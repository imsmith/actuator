defmodule ActuatorWeb.ApiSpecLive.Form do
  @moduledoc "Admin create/edit form for an OpenAPI 3 document."
  use ActuatorWeb, :live_view

  alias Actuator.ApiSpecs
  alias Actuator.ApiSpecs.ApiSpec

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} section={:api_specs}>
      <.breadcrumb items={[
        %{label: "API specs", navigate: ~p"/admin/api_specs"},
        %{label: @page_title}
      ]} />
      <.header>{@page_title}</.header>

      <.form
        for={@form}
        id="api_spec-form"
        phx-change="validate"
        phx-submit="save"
        style="max-width:72ch"
      >
        <.fieldset
          legend="Document"
          hint="An OpenAPI 3 document, JSON or YAML. Base URL defaults to the first server in the spec."
        >
          <.input field={@form[:name]} type="text" label="Name" />
          <.file_drop
            upload={@uploads.file}
            label="Drop a spec or choose a file"
            hint="json · yaml · up to 2 MB"
          />
          <.input field={@form[:source]} type="textarea" label="Source" rows="18" spellcheck="false" />
        </.fieldset>
        <.fieldset
          legend="Calls"
          hint="The auth header is sent verbatim as Authorization on every call."
        >
          <.input
            field={@form[:base_url]}
            type="text"
            label="Base URL"
            placeholder="from spec servers"
          />
          <.input
            field={@form[:auth_header]}
            type="password"
            label="Auth header"
            placeholder="Bearer …"
          />
        </.fieldset>
        <footer class="mt-4 flex justify-end gap-2">
          <.button navigate={return_path(@return_to, @api_spec)}>Cancel</.button>
          <.button type="submit" variant={:primary} icon="m-check" phx-disable-with="Saving">
            Save
          </.button>
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
     |> allow_upload(:file,
       accept: :any,
       max_entries: 1,
       max_file_size: 2_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )
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

  # sobelow_skip ["Traversal.FileModule"]
  # `path` is the temp file LiveView wrote for this upload, not user input.
  defp handle_progress(:file, %{done?: true} = entry, socket) do
    source =
      consume_uploaded_entry(socket, entry, fn %{path: path} -> {:ok, File.read!(path)} end)

    params =
      socket.assigns.form.params
      |> Map.put("source", source)
      |> Map.update("name", name_from(entry.client_name), &blank_or(&1, entry.client_name))

    changeset = ApiSpecs.change_api_spec(socket.assigns.api_spec, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  defp handle_progress(:file, _entry, socket), do: {:noreply, socket}

  defp blank_or("", filename), do: name_from(filename)
  defp blank_or(name, _filename), do: name

  defp name_from(filename) do
    filename |> Path.rootname() |> String.downcase() |> String.replace(~r/[^a-z0-9-]+/, "-")
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
         |> put_flash(:info, "Saved #{api_spec.name}.")
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
         |> put_flash(:info, "Created #{api_spec.name}.")
         |> push_navigate(to: return_path(socket.assigns.return_to, api_spec))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _api_spec), do: ~p"/admin/api_specs"
  defp return_path("show", api_spec), do: ~p"/admin/api_specs/#{api_spec}"
end
