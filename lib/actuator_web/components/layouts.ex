defmodule ActuatorWeb.Layouts do
  @moduledoc """
  The root document and the app shell. Both are composed from gos-ui, the
  Phoenix consumer of the GRID·OPS design system.
  """
  use ActuatorWeb, :html

  embed_templates "layouts/*"

  @sections [
    {:transducers, "Transducers", "m-hub", "/admin/transducers"},
    {:api_specs, "API specs", "m-external", "/admin/api_specs"},
    {:yang_modules, "YANG", "m-tool", "/admin/yang_modules"},
    {:listener, "Listener API", "m-send", "/admin/listener"}
  ]

  @doc """
  The app shell around every admin page: skip link, brand, the section label,
  the sidebar nav, and the flash toasts.

      <Layouts.app flash={@flash} section={:transducers}>
        ...
      </Layouts.app>
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :section, :atom, default: nil, doc: "which nav entry this page belongs to"
  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :items, nav_items())

    ~H"""
    <.skip_link />
    <.app_shell nav_width="12rem">
      <:brand><.mark name="m-hub" size={18} /> ACTUATOR</:brand>
      <:summary>
        <span class="ds-label">{section_label(@section)}</span>
      </:summary>
      <:nav><.menu variant={:sidebar} selected={@section} items={@items} label="Admin" /></:nav>
      {render_slot(@inner_block)}
    </.app_shell>

    <.flash_toasts flash={@flash} />
    <.toast_stack position={:top_right}>
      <.toast
        id="client-error"
        severity={:high}
        duration={0}
        hidden
        phx-disconnected={
          JS.show(to: "#client-error", display: "flex") |> JS.remove_attribute("hidden")
        }
        phx-connected={JS.hide(to: "#client-error") |> JS.set_attribute({"hidden", ""})}
      >
        Connection lost. Reconnecting.
      </.toast>
    </.toast_stack>
    """
  end

  defp nav_items do
    for {id, label, icon, path} <- @sections,
        do: %{id: id, label: label, icon: icon, navigate: path}
  end

  defp section_label(section) do
    Enum.find_value(@sections, "", fn {id, label, _, _} -> id == section && label end)
  end

  @doc """
  Theme and mode attributes for `<html>`, from gos-ui. One theme per
  deployment: `config :actuator, theme: :matrix, mode: :light`.
  """
  def theme_attrs do
    GosUi.theme_attrs(
      Application.get_env(:actuator, :theme, :tron),
      Application.get_env(:actuator, :mode, :dark)
    )
  end
end
