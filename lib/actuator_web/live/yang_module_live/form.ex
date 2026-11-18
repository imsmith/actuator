defmodule ActuatorWeb.YangModuleLive.Form do
  @moduledoc "Admin create/edit form for a YANG module. Name and prefix come from the source."
  use ActuatorWeb, :live_view

  alias Actuator.YangModules
  alias Actuator.YangModules.YangModule

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>
          A YANG module (RFC 7950). Its <code>module</code>
          name and <code>prefix</code>
          are read from the source.
        </:subtitle>
      </.header>

      <.form for={@form} id="yang_module-form" phx-change="validate" phx-submit="save">
        <.file_drop upload={@uploads.file} />
        <.input
          field={@form[:source]}
          type="textarea"
          label="Source"
          rows="18"
          class="w-full rounded-md border border-zinc-300 px-3 py-2 font-mono text-sm"
        />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save YANG module</.button>
          <.button navigate={return_path(@return_to, @yang_module)}>Cancel</.button>
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
    m = YangModules.get_yang_module!(id)

    socket
    |> assign(:page_title, "Edit YANG module")
    |> assign(:yang_module, m)
    |> assign(:form, to_form(YangModules.change_yang_module(m)))
  end

  defp apply_action(socket, :new, _params) do
    m = %YangModule{}

    socket
    |> assign(:page_title, "New YANG module")
    |> assign(:yang_module, m)
    |> assign(:form, to_form(YangModules.change_yang_module(m)))
  end

  # sobelow_skip ["Traversal.FileModule"]
  # `path` is the temp file LiveView wrote for this upload, not user input.
  defp handle_progress(:file, %{done?: true} = entry, socket) do
    source =
      consume_uploaded_entry(socket, entry, fn %{path: path} -> {:ok, File.read!(path)} end)

    params = Map.put(socket.assigns.form.params, "source", source)
    changeset = YangModules.change_yang_module(socket.assigns.yang_module, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  defp handle_progress(:file, _entry, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate", %{"yang_module" => params}, socket) do
    changeset = YangModules.change_yang_module(socket.assigns.yang_module, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"yang_module" => params}, socket) do
    save(socket, socket.assigns.live_action, params)
  end

  defp save(socket, :edit, params) do
    case YangModules.update_yang_module(socket.assigns.yang_module, params) do
      {:ok, m} ->
        {:noreply,
         socket
         |> put_flash(:info, "YANG module updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, m))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save(socket, :new, params) do
    case YangModules.create_yang_module(params) do
      {:ok, m} ->
        {:noreply,
         socket
         |> put_flash(:info, "YANG module created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, m))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _m), do: ~p"/admin/yang_modules"
  defp return_path("show", m), do: ~p"/admin/yang_modules/#{m}"
end
