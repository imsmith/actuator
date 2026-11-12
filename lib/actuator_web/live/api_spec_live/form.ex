defmodule ActuatorWeb.ApiSpecLive.Form do
  @moduledoc "Admin create/edit form for an OpenAPI 3 document."
  use ActuatorWeb, :live_view

  alias Actuator.ApiSpecs
  alias Actuator.ApiSpecs.ApiSpec

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>
          Paste an OpenAPI 3 document, JSON or YAML. Base URL defaults to the first server in the spec.
          The auth header is sent verbatim as <code>Authorization</code> on every call.
        </:subtitle>
      </.header>

      <.form for={@form} id="api_spec-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input
          field={@form[:source]}
          type="textarea"
          label="Source"
          rows="18"
          class="textarea font-mono text-sm w-full"
        />
        <.input field={@form[:base_url]} type="text" label="Base URL" placeholder="from spec servers" />
        <.input
          field={@form[:auth_header]}
          type="password"
          label="Auth header"
          placeholder="Bearer …"
        />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save API spec</.button>
          <.button navigate={return_path(@return_to, @api_spec)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    api_spec = ApiSpecs.get_api_spec!(id)

    socket
    |> assign(:page_title, "Edit API spec")
    |> assign(:api_spec, api_spec)
    |> assign(:form, to_form(ApiSpecs.change_api_spec(api_spec)))
  end

  defp apply_action(socket, :new, _params) do
    api_spec = %ApiSpec{}

    socket
    |> assign(:page_title, "New API spec")
    |> assign(:api_spec, api_spec)
    |> assign(:form, to_form(ApiSpecs.change_api_spec(api_spec)))
  end

  @impl true
  def handle_event("validate", %{"api_spec" => api_spec_params}, socket) do
    changeset = ApiSpecs.change_api_spec(socket.assigns.api_spec, api_spec_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"api_spec" => api_spec_params}, socket) do
    save_api_spec(socket, socket.assigns.live_action, api_spec_params)
  end

  defp save_api_spec(socket, :edit, api_spec_params) do
    case ApiSpecs.update_api_spec(socket.assigns.api_spec, api_spec_params) do
      {:ok, api_spec} ->
        {:noreply,
         socket
         |> put_flash(:info, "API spec updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, api_spec))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_api_spec(socket, :new, api_spec_params) do
    case ApiSpecs.create_api_spec(api_spec_params) do
      {:ok, api_spec} ->
        {:noreply,
         socket
         |> put_flash(:info, "API spec created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, api_spec))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _api_spec), do: ~p"/admin/api_specs"
  defp return_path("show", api_spec), do: ~p"/admin/api_specs/#{api_spec}"
end
