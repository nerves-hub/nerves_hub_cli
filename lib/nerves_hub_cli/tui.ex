defmodule NervesHubCLI.TUI do
  use TermUI.Elm

  alias TermUI.Event
  alias TermUI.Renderer.Style
  alias NervesHubCLI.API

  import TermUI.Helpers.BorderHelper

  @org_menu [
    {"Products", :products},
    {"Signing Keys", :keys},
    {"CA Certificates", :ca_certs},
    {"Org Users", :org_users}
  ]

  @product_menu [
    {"Devices", :devices},
    {"Firmwares", :firmwares},
    {"Deployments", :deployments},
    {"Scripts", :scripts},
    {"Product Users", :product_users}
  ]

  @device_menu [
    {"Details", :device_detail},
    {"Certificates", :device_certs}
  ]

  defstruct [
    :auth,
    :error,
    :runtime_pid,
    :org,
    :selected_product,
    :selected_device,
    :selected_deployment,
    :detail_data,
    :api_status,
    view: :org_select,
    org_input: "",
    known_orgs: [],
    items: [],
    cursor: 0,
    loading: false,
    term_width: 80,
    term_height: 24,
    theme: %{}
  ]

  # --- Theme ---

  defp default_theme do
    %{
      header: Style.new(fg: :cyan, attrs: [:bold]),
      breadcrumb: Style.new(fg: :yellow),
      cursor: Style.new(fg: :green, attrs: [:bold]),
      cursor_alt: Style.new(fg: :yellow, attrs: [:bold]),
      muted: Style.new(fg: :bright_black),
      text: Style.new(fg: :white),
      label: Style.new(fg: :cyan),
      detail_heading: Style.new(fg: :cyan, attrs: [:bold]),
      border: Style.new(fg: :bright_black),
      error: Style.new(fg: :red),
      error_border: Style.new(fg: :red),
      footer: Style.new(fg: :bright_black),
      status_bar: Style.new(fg: :bright_black, attrs: [:dim]),
      loading: Style.new(fg: :bright_black),
      empty: Style.new(fg: :bright_black),
      active: Style.new(fg: :green),
      inactive: Style.new(fg: :bright_black),
      col_secondary: Style.new(fg: :bright_black)
    }
  end

  def run do
    auth = NervesHubCLI.CLI.Shell.request_auth()
    org = NervesHubCLI.Config.org()
    TermUI.Runtime.run(root: __MODULE__, auth: auth, org: org)
    System.halt(0)
  end

  @impl true
  def init(opts) do
    auth = Keyword.fetch!(opts, :auth)
    org = opts[:org]
    runtime_pid = self()
    known_orgs = discover_orgs()
    term_width = case :io.columns() do
      {:ok, cols} -> cols
      _ -> 80
    end
    term_height = case :io.rows() do
      {:ok, rows} -> rows
      _ -> 24
    end

    state = %__MODULE__{
      auth: auth,
      runtime_pid: runtime_pid,
      known_orgs: known_orgs,
      term_width: term_width,
      term_height: term_height,
      theme: default_theme()
    }

    if org do
      %{state | org: org, view: :org_menu}
    else
      %{state | view: :org_select}
    end
  end

  defp discover_orgs do
    keys_dir = Path.join(NervesHubCLI.data_dir(), "keys")

    case File.ls(keys_dir) do
      {:ok, entries} ->
        entries
        |> Enum.filter(&(Path.join(keys_dir, &1) |> File.dir?()))
        |> Enum.sort()

      _ ->
        []
    end
  end

  def handle_info({:tui_async, msg}, state), do: update(msg, state)
  def handle_info(_msg, state), do: state

  # --- Events ---

  @impl true
  # Org select (list of known orgs)
  def event_to_msg(%Event.Key{key: :escape}, %{view: :org_select}), do: {:msg, :quit}
  def event_to_msg(%Event.Key{key: :up}, %{view: :org_select}), do: {:msg, :cursor_up}
  def event_to_msg(%Event.Key{key: :down}, %{view: :org_select}), do: {:msg, :cursor_down}
  def event_to_msg(%Event.Key{key: "k"}, %{view: :org_select}), do: {:msg, :cursor_up}
  def event_to_msg(%Event.Key{key: "j"}, %{view: :org_select}), do: {:msg, :cursor_down}
  def event_to_msg(%Event.Key{key: :enter}, %{view: :org_select}), do: {:msg, :select}
  def event_to_msg(%Event.Key{key: "/"}, %{view: :org_select}), do: {:msg, :org_type_custom}

  # Org text input mode
  def event_to_msg(%Event.Key{key: :escape}, %{view: :org_input}), do: {:msg, :org_cancel_input}
  def event_to_msg(%Event.Key{key: :enter}, %{view: :org_input}), do: {:msg, :org_submit}
  def event_to_msg(%Event.Key{key: :backspace}, %{view: :org_input}), do: {:msg, :org_backspace}

  def event_to_msg(%Event.Key{key: key}, %{view: :org_input})
      when is_binary(key) and byte_size(key) == 1,
      do: {:msg, {:org_char, key}}

  # Resize
  def event_to_msg(%Event.Resize{width: w, height: h}, _state), do: {:msg, {:resize, w, h}}

  # Global quit (not in org input/select modes)
  def event_to_msg(%Event.Key{key: "q"}, _state), do: {:msg, :quit}

  # Navigation
  def event_to_msg(%Event.Key{key: :escape}, _state), do: {:msg, :back}
  def event_to_msg(%Event.Key{key: :up}, _state), do: {:msg, :cursor_up}
  def event_to_msg(%Event.Key{key: :down}, _state), do: {:msg, :cursor_down}
  def event_to_msg(%Event.Key{key: :enter}, _state), do: {:msg, :select}
  def event_to_msg(%Event.Key{key: "k"}, _state), do: {:msg, :cursor_up}
  def event_to_msg(%Event.Key{key: "j"}, _state), do: {:msg, :cursor_down}
  def event_to_msg(%Event.Key{key: "r"}, _state), do: {:msg, :refresh}
  def event_to_msg(_, _), do: :ignore

  # --- Update ---

  @impl true
  def update(:quit, state), do: {state, [:quit]}

  def update({:resize, width, height}, state),
    do: {%{state | term_width: width, term_height: height}, []}

  # Org select list
  def update(:select, %{view: :org_select} = state) do
    # Last item is always "Other..." for custom input
    org_options = state.known_orgs ++ ["Other..."]

    case Enum.at(org_options, state.cursor) do
      "Other..." ->
        {%{state | view: :org_input, org_input: "", cursor: 0}, []}

      nil ->
        {state, []}

      org ->
        {%{state | org: org, view: :org_menu, cursor: 0, error: nil}, []}
    end
  end

  def update(:org_type_custom, %{view: :org_select} = state) do
    {%{state | view: :org_input, org_input: "", cursor: 0}, []}
  end

  # Org text input
  def update({:org_char, char}, %{view: :org_input} = state),
    do: {%{state | org_input: state.org_input <> char}, []}

  def update(:org_backspace, %{view: :org_input} = state) do
    trimmed = String.slice(state.org_input, 0, max(String.length(state.org_input) - 1, 0))
    {%{state | org_input: trimmed}, []}
  end

  def update(:org_cancel_input, %{view: :org_input} = state) do
    {%{state | view: :org_select, org_input: "", cursor: 0}, []}
  end

  def update(:org_submit, %{view: :org_input} = state) do
    org = String.trim(state.org_input)

    if org == "" do
      {state, []}
    else
      {%{state | org: org, org_input: "", view: :org_menu, cursor: 0, error: nil}, []}
    end
  end

  # Back navigation
  def update(:back, %{view: :org_menu} = state),
    do: {%{state | view: :org_select, cursor: 0, error: nil}, []}

  def update(:back, %{view: v} = state) when v in [:products, :keys, :ca_certs, :org_users],
    do: {%{state | view: :org_menu, items: [], cursor: 0, error: nil}, []}

  def update(:back, %{view: :product_menu} = state),
    do: {%{state | view: :products, selected_product: nil, cursor: 0, error: nil, items: []}, []}

  def update(:back, %{view: v} = state)
      when v in [:devices, :firmwares, :deployments, :scripts, :product_users],
      do: {%{state | view: :product_menu, items: [], cursor: 0, error: nil}, []}

  def update(:back, %{view: :device_menu} = state),
    do: {%{state | view: :devices, selected_device: nil, cursor: 0, error: nil, items: []}, []}

  def update(:back, %{view: v} = state) when v in [:device_detail, :device_certs],
    do: {%{state | view: :device_menu, items: [], cursor: 0, error: nil, detail_data: nil}, []}

  def update(:back, %{view: :deployment_detail} = state),
    do: {%{state | view: :deployments, cursor: 0, error: nil, detail_data: nil}, []}

  def update(:back, state), do: {state, []}

  # Cursor
  def update(:cursor_up, state),
    do: {%{state | cursor: max(state.cursor - 1, 0)}, []}

  def update(:cursor_down, state) do
    max_idx = max(list_length(state) - 1, 0)
    {%{state | cursor: min(state.cursor + 1, max_idx)}, []}
  end

  # Refresh current view
  def update(:refresh, %{loading: true} = state), do: {state, []}
  def update(:refresh, state), do: update(:navigate_current, state)

  # Org menu selection
  def update(:select, %{view: :org_menu} = state) do
    case Enum.at(@org_menu, state.cursor) do
      {_, target} -> navigate(state, target)
      nil -> {state, []}
    end
  end

  # Product menu selection
  def update(:select, %{view: :product_menu} = state) do
    case Enum.at(@product_menu, state.cursor) do
      {_, target} -> navigate(state, target)
      nil -> {state, []}
    end
  end

  # Device menu selection
  def update(:select, %{view: :device_menu} = state) do
    case Enum.at(@device_menu, state.cursor) do
      {_, target} -> navigate(state, target)
      nil -> {state, []}
    end
  end

  # Products list -> product menu
  def update(:select, %{view: :products, loading: false} = state) do
    case Enum.at(state.items, state.cursor) do
      nil -> {state, []}
      product -> {%{state | selected_product: product["name"], view: :product_menu, cursor: 0, items: []}, []}
    end
  end

  # Devices list -> device menu
  def update(:select, %{view: :devices, loading: false} = state) do
    case Enum.at(state.items, state.cursor) do
      nil ->
        {state, []}

      device ->
        id = device["identifier"]

        {%{state | selected_device: id, view: :device_menu, cursor: 0, items: [],
           detail_data: device}, []}
    end
  end

  # Deployments list -> deployment detail
  def update(:select, %{view: :deployments, loading: false} = state) do
    case Enum.at(state.items, state.cursor) do
      nil ->
        {state, []}

      deployment ->
        {%{state | selected_deployment: deployment["name"], view: :deployment_detail,
           detail_data: deployment, cursor: 0}, []}
    end
  end

  # Detail views and non-selectable lists: no-op
  def update(:select, state), do: {state, []}

  # Navigate to a data view (triggers async load)
  def update({:navigate, target}, state), do: navigate(state, target)
  def update(:navigate_current, state), do: navigate(state, state.view)

  # Async results
  def update({:loaded, view, items, time_ms}, state) do
    api_status = %{status: "OK", time_ms: time_ms}
    {%{state | view: view, items: items, loading: false, error: nil, cursor: 0, api_status: api_status}, []}
  end

  def update({:loaded_detail, view, data, time_ms}, state) do
    api_status = %{status: "OK", time_ms: time_ms}
    {%{state | view: view, detail_data: data, loading: false, error: nil, api_status: api_status}, []}
  end

  def update({:error, error, time_ms}, state) do
    api_status = %{status: "Error", time_ms: time_ms}
    {%{state | error: format_error(error), loading: false, api_status: api_status}, []}
  end

  # Legacy fallbacks (without timing)
  def update({:loaded, view, items}, state),
    do: {%{state | view: view, items: items, loading: false, error: nil, cursor: 0}, []}

  def update({:error, error}, state),
    do: {%{state | error: format_error(error), loading: false}, []}

  def update(_, state), do: {state, []}

  # --- Navigation / loading ---

  defp navigate(state, :products) do
    load(state, :products, fn ->
      load_list(&API.Product.list(state.org, &1), :products)
    end)
  end

  defp navigate(state, :keys) do
    load(state, :keys, fn -> load_list(&API.Key.list(state.org, &1), :keys) end)
  end

  defp navigate(state, :ca_certs) do
    load(state, :ca_certs, fn -> load_list(&API.CACertificate.list(state.org, &1), :ca_certs) end)
  end

  defp navigate(state, :org_users) do
    load(state, :org_users, fn -> load_list(&API.OrgUser.list(state.org, &1), :org_users) end)
  end

  defp navigate(state, :devices) do
    load(state, :devices, fn ->
      load_list(&API.Device.list(state.org, state.selected_product, &1), :devices)
    end)
  end

  defp navigate(state, :firmwares) do
    load(state, :firmwares, fn ->
      load_list(&API.Firmware.list(state.org, state.selected_product, &1), :firmwares)
    end)
  end

  defp navigate(state, :deployments) do
    load(state, :deployments, fn ->
      load_list(&API.Deployment.list(state.org, state.selected_product, &1), :deployments)
    end)
  end

  defp navigate(state, :scripts) do
    load(state, :scripts, fn ->
      load_list(&API.Script.list(state.org, state.selected_product, &1), :scripts)
    end)
  end

  defp navigate(state, :product_users) do
    load(state, :product_users, fn ->
      load_list(&API.ProductUser.list(state.org, state.selected_product, &1), :product_users)
    end)
  end

  defp navigate(state, :device_detail) do
    {%{state | view: :device_detail, cursor: 0}, []}
  end

  defp navigate(state, :device_certs) do
    load(state, :device_certs, fn ->
      load_list(
        &API.DeviceCertificate.list(state.org, state.selected_product, state.selected_device, &1),
        :device_certs
      )
    end)
  end

  defp navigate(state, _), do: {state, []}

  defp load(state, view, loader) do
    auth = state.auth

    spawn_async(state, fn ->
      loader.().(auth)
    end)

    {%{state | view: view, loading: true, cursor: 0, error: nil}, []}
  end

  defp load_list(api_fn, view, mapper \\ &Function.identity/1) do
    fn auth ->
      start = System.monotonic_time(:millisecond)

      result = api_fn.(auth)

      time_ms = System.monotonic_time(:millisecond) - start

      case result do
        {:ok, %{"data" => items}} when is_list(items) ->
          {:loaded, view, Enum.map(items, mapper), time_ms}

        {:error, reason} ->
          {:error, reason, time_ms}

        other ->
          {:error, "Unexpected: #{inspect(other)}", time_ms}
      end
    end
  end

  # --- View ---

  @impl true
  def view(state) do
    t = state.theme

    children = [
      view_header(state, t),
      text(""),
      view_body(state, t),
      text("")
    ]

    children = if state.error do
      children ++ [view_error_box(state, t), text("")]
    else
      children
    end

    children = children ++ [
      view_footer(state, t),
      view_status_bar(state, t)
    ]

    stack(:vertical, children)
  end

  defp view_header(state, t) do
    stack(:vertical, [
      text("NervesHub Browser", t.header),
      text(breadcrumb(state), t.breadcrumb)
    ])
  end

  defp breadcrumb(state) do
    parts = [state.org]

    parts =
      case state.view do
        v when v in [:org_select, :org_input, :org_menu] -> parts
        v when v in [:products, :keys, :ca_certs, :org_users] -> parts ++ [view_label(v)]
        :product_menu -> parts ++ [state.selected_product]
        :device_menu -> parts ++ [state.selected_product, state.selected_device]
        :deployment_detail ->
          parts ++ [state.selected_product, "Deployments", state.selected_deployment]
        v when v in [:device_detail, :device_certs] ->
          parts ++ [state.selected_product, state.selected_device, view_label(v)]
        v ->
          parts ++ [state.selected_product, view_label(v)]
      end

    parts |> Enum.reject(&is_nil/1) |> Enum.join(" > ")
  end

  defp view_label(:org_select), do: "Select Organization"
  defp view_label(:org_input), do: "Enter Organization"
  defp view_label(:org_menu), do: nil
  defp view_label(:products), do: "Products"
  defp view_label(:keys), do: "Signing Keys"
  defp view_label(:ca_certs), do: "CA Certificates"
  defp view_label(:org_users), do: "Org Users"
  defp view_label(:product_menu), do: nil
  defp view_label(:devices), do: "Devices"
  defp view_label(:firmwares), do: "Firmwares"
  defp view_label(:deployments), do: "Deployments"
  defp view_label(:scripts), do: "Scripts"
  defp view_label(:product_users), do: "Product Users"
  defp view_label(:device_menu), do: nil
  defp view_label(:device_detail), do: "Details"
  defp view_label(:device_certs), do: "Certificates"
  defp view_label(:deployment_detail), do: "Detail"
  defp view_label(_), do: nil

  # Body - split pane layout

  defp view_body(%{view: :org_select} = state, t) do
    org_options = state.known_orgs ++ ["Other..."]

    nodes =
      org_options
      |> Enum.with_index()
      |> Enum.map(fn {org, idx} ->
        style =
          if org == "Other..." do
            if idx == state.cursor, do: t.cursor_alt, else: t.muted
          else
            if idx == state.cursor, do: t.cursor, else: nil
          end

        if idx == state.cursor do
          text("> " <> org, style)
        else
          text("  " <> org, style)
        end
      end)

    stack(:vertical, [
      text("Select an organization:", t.text),
      text("") | nodes
    ])
  end

  defp view_body(%{view: :org_input} = state, t) do
    text("Organization: " <> state.org_input <> "_", t.text)
  end

  defp view_body(%{loading: true} = state, t) do
    left_width = div(state.term_width, 2)
    right_width = state.term_width - left_width

    stack(:horizontal, [
      box([text("Loading...", t.loading)], width: left_width),
      framed_panel("", [text("")], right_width, t)
    ])
  end

  defp view_body(state, t) do
    left_width = div(state.term_width, 2)
    right_width = state.term_width - left_width
    detail = detail_panel(state, t)
    title = detail_title(state)
    # Reserve lines for: header(2) + blank + blank + footer + status_bar + error(~4 if present)
    max_visible = max(state.term_height - 8, 5)

    stack(:horizontal, [
      box([nav_panel(state, t, max_visible)], width: left_width),
      framed_panel(title, detail, right_width, t)
    ])
  end

  # Left navigation panel

  defp nav_panel(%{view: :org_menu} = state, t, _mv), do: render_menu(@org_menu, state.cursor, t)
  defp nav_panel(%{view: :product_menu} = state, t, _mv), do: render_menu(@product_menu, state.cursor, t)
  defp nav_panel(%{view: :device_menu} = state, t, _mv), do: render_menu(@device_menu, state.cursor, t)

  defp nav_panel(%{view: :products} = state, t, mv),
    do: render_name_list(state.items, state.cursor, "name", "No products.", t, mv)

  defp nav_panel(%{view: :keys} = state, t, mv),
    do: render_name_list(state.items, state.cursor, "name", "No signing keys.", t, mv)

  defp nav_panel(%{view: :ca_certs} = state, t, mv),
    do: render_row_list(state.items, state.cursor, &ca_cert_row/2, "No CA certificates.", t, mv)

  defp nav_panel(%{view: :org_users} = state, t, mv),
    do: render_row_list(state.items, state.cursor, &user_row/2, "No users.", t, mv)

  defp nav_panel(%{view: :product_users} = state, t, mv),
    do: render_row_list(state.items, state.cursor, &user_row/2, "No users.", t, mv)

  defp nav_panel(%{view: :devices} = state, t, mv),
    do: render_row_list(state.items, state.cursor, &device_row/2, "No devices.", t, mv)

  defp nav_panel(%{view: :firmwares} = state, t, mv),
    do: render_row_list(state.items, state.cursor, &firmware_row/2, "No firmwares.", t, mv)

  defp nav_panel(%{view: :deployments} = state, t, mv),
    do: render_row_list(state.items, state.cursor, &deployment_row/2, "No deployments.", t, mv)

  defp nav_panel(%{view: :scripts} = state, t, mv),
    do: render_name_list(state.items, state.cursor, "name", "No scripts.", t, mv)

  defp nav_panel(%{view: :device_detail}, t, _mv),
    do: render_menu(@device_menu, 0, t)

  defp nav_panel(%{view: :device_certs} = state, t, mv),
    do: render_name_list(state.items, state.cursor, "serial", "No certificates.", t, mv)

  defp nav_panel(%{view: :deployment_detail} = state, t, _mv) do
    text(state.selected_deployment || "Deployment", t.cursor)
  end

  defp nav_panel(_state, _t, _mv), do: empty()

  # Right detail panel - returns list of render nodes for framed rendering

  defp detail_title(%{view: v}) when v in [:org_menu, :product_menu, :device_menu], do: "Info"
  defp detail_title(%{view: :products}), do: "Product"
  defp detail_title(%{view: :keys}), do: "Key"
  defp detail_title(%{view: :ca_certs}), do: "Certificate"
  defp detail_title(%{view: v}) when v in [:org_users, :product_users], do: "User"
  defp detail_title(%{view: :devices}), do: "Device"
  defp detail_title(%{view: :firmwares}), do: "Firmware"
  defp detail_title(%{view: :deployments}), do: "Deployment"
  defp detail_title(%{view: :deployment_detail}), do: "Deployment"
  defp detail_title(%{view: :scripts}), do: "Script"
  defp detail_title(%{view: :device_detail}), do: "Device"
  defp detail_title(%{view: :device_certs}), do: "Certificate"
  defp detail_title(_), do: "Details"

  defp detail_panel(%{view: :org_menu} = state, t) do
    menu_descriptions = %{
      products: "Browse and manage products for this organization.",
      keys: "View signing keys used for firmware authentication.",
      ca_certs: "View CA certificates for device authentication.",
      org_users: "View and manage organization members."
    }

    case Enum.at(@org_menu, state.cursor) do
      {label, key} ->
        [text(label, t.detail_heading), text(""), text(menu_descriptions[key] || "")]
      _ ->
        [text("")]
    end
  end

  defp detail_panel(%{view: :product_menu} = state, t) do
    menu_descriptions = %{
      devices: "Browse devices registered to this product.",
      firmwares: "View uploaded firmware images.",
      deployments: "Manage firmware deployment groups.",
      scripts: "View support scripts for devices.",
      product_users: "View and manage product-level access."
    }

    case Enum.at(@product_menu, state.cursor) do
      {label, key} ->
        [text(label, t.detail_heading), text(""), text(menu_descriptions[key] || "")]
      _ ->
        [text("")]
    end
  end

  defp detail_panel(%{view: :device_menu} = state, t) do
    menu_descriptions = %{
      device_detail: "View detailed device information and metadata.",
      device_certs: "View device authentication certificates."
    }

    case Enum.at(@device_menu, state.cursor) do
      {label, key} ->
        [text(label, t.detail_heading), text(""), text(menu_descriptions[key] || "")]
      _ ->
        [text("")]
    end
  end

  defp detail_panel(%{view: :products} = state, t) do
    case Enum.at(state.items, state.cursor) do
      nil -> [text("")]
      p -> detail_fields([{"Name", p["name"]}, {"Delta Updatable", p["delta_updatable"]}], t)
    end
  end

  defp detail_panel(%{view: :keys} = state, t) do
    case Enum.at(state.items, state.cursor) do
      nil -> [text("")]
      k -> detail_fields([{"Name", k["name"]}, {"Public Key", k["key"]}], t)
    end
  end

  defp detail_panel(%{view: :ca_certs} = state, t) do
    case Enum.at(state.items, state.cursor) do
      nil -> [text("")]
      c -> detail_fields([
        {"Serial", c["serial"]}, {"Description", c["description"]},
        {"Not Before", c["not_before"]}, {"Not After", c["not_after"]}
      ], t)
    end
  end

  defp detail_panel(%{view: v} = state, t) when v in [:org_users, :product_users] do
    case Enum.at(state.items, state.cursor) do
      nil -> [text("")]
      u -> detail_fields([{"Email", u["email"]}, {"Role", u["role"]}], t)
    end
  end

  defp detail_panel(%{view: :devices} = state, t) do
    case Enum.at(state.items, state.cursor) do
      nil -> [text("")]
      d -> detail_fields([
        {"Identifier", d["identifier"]}, {"Status", d["status"]},
        {"Version", d["version"]}, {"Tags", Enum.join(d["tags"] || [], ", ")},
        {"Last connected", d["last_communication"]}
      ], t)
    end
  end

  defp detail_panel(%{view: :firmwares} = state, t) do
    case Enum.at(state.items, state.cursor) do
      nil -> [text("")]
      fw -> detail_fields([
        {"Version", fw["version"]}, {"Platform", fw["platform"]},
        {"Architecture", fw["architecture"]}, {"UUID", fw["uuid"]}
      ], t)
    end
  end

  defp detail_panel(%{view: :deployments} = state, t) do
    case Enum.at(state.items, state.cursor) do
      nil -> [text("")]
      dep ->
        conditions = dep["conditions"] || %{}
        firmware = dep["firmware"] || %{}
        detail_fields([
          {"Name", dep["name"]},
          {"State", if(dep["is_active"], do: "active", else: "inactive")},
          {"Firmware Version", firmware["version"]},
          {"Firmware UUID", firmware["uuid"] || dep["firmware_uuid"]},
          {"Tags", Enum.join(conditions["tags"] || [], ", ")},
          {"Version Condition", conditions["version"]}
        ], t)
    end
  end

  defp detail_panel(%{view: :scripts} = state, t) do
    case Enum.at(state.items, state.cursor) do
      nil -> [text("")]
      s -> detail_fields([{"Name", s["name"]}, {"ID", s["id"]}, {"Tags", Enum.join(s["tags"] || [], ", ")}], t)
    end
  end

  defp detail_panel(%{view: :device_detail} = state, t) do
    case state.detail_data do
      nil -> [text("No device data.", t.empty)]
      d -> detail_fields([
        {"Identifier", d["identifier"]}, {"Status", d["status"]},
        {"Version", d["version"]}, {"Description", d["description"]},
        {"Tags", Enum.join(d["tags"] || [], ", ")},
        {"Last connected", d["last_communication"]},
        {"Firmware UUID", get_in(d, ["firmware_metadata", "uuid"])},
        {"Firmware Platform", get_in(d, ["firmware_metadata", "platform"])},
        {"Firmware Arch", get_in(d, ["firmware_metadata", "architecture"])}
      ], t)
    end
  end

  defp detail_panel(%{view: :device_certs} = state, t) do
    case Enum.at(state.items, state.cursor) do
      nil -> [text("")]
      c -> detail_fields([{"Serial", c["serial"]}, {"Not Before", c["not_before"]}, {"Not After", c["not_after"]}], t)
    end
  end

  defp detail_panel(%{view: :deployment_detail} = state, t) do
    case state.detail_data do
      nil -> [text("No deployment data.", t.empty)]
      dep ->
        conditions = dep["conditions"] || %{}
        firmware = dep["firmware"] || %{}
        detail_fields([
          {"Name", dep["name"]},
          {"State", if(dep["is_active"], do: "active", else: "inactive")},
          {"Firmware UUID", firmware["uuid"] || dep["firmware_uuid"]},
          {"Firmware Version", firmware["version"]},
          {"Firmware Platform", firmware["platform"]},
          {"Firmware Arch", firmware["architecture"]},
          {"Condition: Tags", Enum.join(conditions["tags"] || [], ", ")},
          {"Condition: Version", conditions["version"]}
        ], t)
    end
  end

  defp detail_panel(_state, _t), do: [text("")]

  defp detail_fields(fields, t) do
    Enum.map(fields, fn {label, value} ->
      val = to_string(value || "-")
      stack(:horizontal, [
        text(pad(label <> ":", 20), t.label),
        text(" " <> val)
      ])
    end)
  end

  # Framed panel with border

  defp framed_panel(title, content_nodes, width, t) when width >= 4 do
    inner_width = width - 2

    # Title in top border
    title_str = if title != "", do: " " <> title <> " ", else: ""
    title_len = String.length(title_str)
    remaining = max(0, inner_width - title_len)
    chars = TermUI.CharacterSet.current_charset()
    top = chars.tl <> title_str <> String.duplicate(chars.h_line, remaining) <> chars.tr

    bottom = box_bottom(width)

    # Wrap each content line in borders
    content_rows = Enum.map(content_nodes, fn node ->
      stack(:horizontal, [
        text(chars.v_line <> " ", t.border),
        node
      ])
    end)

    stack(:vertical, [
      text(top, t.border)
    ] ++ content_rows ++ [
      text(bottom, t.border)
    ])
  end

  defp framed_panel(_title, content_nodes, _width, _t), do: stack(:vertical, content_nodes)

  # Error status box

  defp view_error_box(state, t) do
    width = state.term_width
    chars = TermUI.CharacterSet.current_charset()

    error_text = "Error: " <> (state.error || "unknown")
    inner = max(0, width - 2)
    top = chars.tl <> String.duplicate(chars.h_line, inner) <> chars.tr
    bottom = chars.bl <> String.duplicate(chars.h_line, inner) <> chars.br

    stack(:vertical, [
      text(top, t.error_border),
      stack(:horizontal, [
        text(chars.v_line <> " ", t.error_border),
        text(error_text, t.error)
      ]),
      text(bottom, t.error_border)
    ])
  end

  # Footer

  defp view_footer(state, t) do
    nav =
      case state.view do
        :org_select -> "Enter: select  |  /: type org name  |  Esc: quit"
        :org_input -> "Enter: confirm  |  Esc: back to list"
        :org_menu -> "Enter: select  |  Esc: switch org  |  q: quit"
        :product_menu -> "Enter: select  |  Esc: back  |  q: quit"
        :device_menu -> "Enter: select  |  Esc: back  |  q: quit"
        v when v in [:products, :devices, :deployments] ->
          "Enter: open  |  r: refresh  |  Esc: back  |  q: quit"
        v when v in [:device_detail, :deployment_detail] ->
          "Esc: back  |  q: quit"
        _ -> "r: refresh  |  Esc: back  |  q: quit"
      end

    text(nav, t.footer)
  end

  # Status bar

  defp view_status_bar(state, t) do
    status_text = case state.api_status do
      %{status: status, time_ms: ms} ->
        "API: #{status} (#{ms}ms)"
      nil ->
        ""
    end

    text(status_text, t.status_bar)
  end

  # --- Renderers ---

  defp render_menu(menu, cursor, t) do
    items =
      menu
      |> Enum.with_index()
      |> Enum.map(fn {{label, _}, idx} -> render_cursor(label, idx, cursor, t) end)

    stack(:vertical, items)
  end

  defp render_name_list(items, cursor, key, empty_msg, t, max_visible) do
    if items == [] do
      text(empty_msg, t.empty)
    else
      {visible, offset} = scroll_window(items, cursor, max_visible)

      nodes =
        visible
        |> Enum.with_index()
        |> Enum.map(fn {item, vi} ->
          idx = vi + offset
          label = to_string(item[key] || "?")
          render_cursor(label, idx, cursor, t)
        end)

      wrap_scroll_indicators(nodes, offset, length(items), max_visible, t)
    end
  end

  defp render_row_list(items, cursor, row_fn, empty_msg, t, max_visible) do
    if items == [] do
      text(empty_msg, t.empty)
    else
      {visible, offset} = scroll_window(items, cursor, max_visible)

      nodes =
        visible
        |> Enum.with_index()
        |> Enum.map(fn {item, vi} ->
          idx = vi + offset
          prefix = if idx == cursor, do: "> ", else: "  "
          row = row_fn.(item, t)
          selected_style = if idx == cursor, do: t.cursor, else: nil

          stack(:horizontal, [text(prefix, selected_style) | row])
        end)

      wrap_scroll_indicators(nodes, offset, length(items), max_visible, t)
    end
  end

  defp scroll_window(items, cursor, max_visible) do
    total = length(items)

    if total <= max_visible do
      {items, 0}
    else
      # Keep cursor visible with some context
      offset = cursor - div(max_visible, 2)
      offset = max(offset, 0)
      offset = min(offset, total - max_visible)
      visible = Enum.slice(items, offset, max_visible)
      {visible, offset}
    end
  end

  defp wrap_scroll_indicators(nodes, offset, total, max_visible, t) do
    above = offset > 0
    below = offset + max_visible < total

    top = if above, do: [text("  ▲ #{offset} more", t.muted)], else: []
    bottom = if below, do: [text("  ▼ #{total - offset - max_visible} more", t.muted)], else: []

    stack(:vertical, top ++ nodes ++ bottom)
  end

  # Row renderers for table-style nav lists

  defp device_row(d, t) do
    id = d["identifier"] || "?"
    ver = get_in(d, ["firmware_metadata", "version"]) || d["version"] || ""
    ver_str = if ver != "", do: " v#{ver}", else: ""

    [
      text(id),
      text(ver_str, t.col_secondary)
    ]
  end

  defp deployment_row(dep, t) do
    active? = dep["is_active"]
    dot_style = if active?, do: t.active, else: t.inactive
    name = dep["name"] || "?"
    fw_ver = get_in(dep, ["firmware", "version"]) || ""
    fw_str = if fw_ver != "", do: " (#{fw_ver})", else: ""

    [
      text("● ", dot_style),
      text(name),
      text(fw_str, t.col_secondary)
    ]
  end

  defp firmware_row(fw, t) do
    ver = fw["version"] || "?"
    plat = fw["platform"] || ""
    arch = fw["architecture"] || ""
    suffix = [plat, arch] |> Enum.reject(&(&1 == "")) |> Enum.join("/")
    suffix_str = if suffix != "", do: " #{suffix}", else: ""

    [
      text(ver),
      text(suffix_str, t.col_secondary)
    ]
  end

  defp user_row(u, t) do
    email = u["email"] || "?"
    role = u["role"] || ""
    role_str = if role != "", do: " (#{role})", else: ""

    [
      text(email),
      text(role_str, t.col_secondary)
    ]
  end

  defp ca_cert_row(c, t) do
    serial = to_string(c["serial"] || "?")
    not_after = c["not_after"] || ""
    expiry_str = if not_after != "", do: " exp:#{not_after}", else: ""

    [
      text(serial),
      text(expiry_str, t.col_secondary)
    ]
  end

  # --- Helpers ---

  defp render_cursor(label, idx, cursor, t) do
    if idx == cursor do
      text("> " <> label, t.cursor)
    else
      text("  " <> label)
    end
  end

  defp pad(str, width) do
    s = to_string(str || "")
    len = String.length(s)
    if len >= width, do: s, else: s <> String.duplicate(" ", width - len)
  end

  defp list_length(%{view: :org_select} = state), do: length(state.known_orgs) + 1
  defp list_length(%{view: :org_menu}), do: length(@org_menu)
  defp list_length(%{view: :product_menu}), do: length(@product_menu)
  defp list_length(%{view: :device_menu}), do: length(@device_menu)
  defp list_length(%{items: items}), do: length(items)

  defp spawn_async(state, fun) do
    pid = state.runtime_pid
    spawn(fn -> send(pid, {:tui_async, fun.()}) end)
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(%{"status" => status}), do: to_string(status)
  defp format_error(%{"errors" => %{"detail" => detail}}), do: detail
  defp format_error(%{"errors" => errors}) when is_binary(errors), do: errors
  defp format_error(error), do: inspect(error, pretty: true, limit: 5)
end
