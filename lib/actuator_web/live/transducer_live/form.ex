defmodule ActuatorWeb.TransducerLive.Form do
  @moduledoc "Admin create/edit form. The net is validated on every change."
  use ActuatorWeb, :live_view

  alias Actuator.Transducers
  alias Actuator.Transducers.Transducer

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} section={:transducers}>
      <.breadcrumb items={[
        %{label: "Transducers", navigate: ~p"/admin/transducers"},
        %{label: @page_title}
      ]} />
      <.header>{@page_title}</.header>

      <.form
        for={@form}
        id="transducer-form"
        phx-change="validate"
        phx-submit="save"
        style="max-width:72ch"
      >
        <.fieldset
          legend="Definition"
          hint="A cpn-spec 1.0 net. Parsed and validated on every change."
        >
          <.input field={@form[:name]} type="text" label="Name" />
          <.file_drop
            upload={@uploads.file}
            label="Drop a net or choose a file"
            hint="tcl · cpn · up to 2 MB"
          />
          <.input field={@form[:source]} type="textarea" label="Source" rows="18" spellcheck="false" />
          <.input field={@form[:entry_place]} type="text" label="Entry place" />
          <.input field={@form[:enabled]} type="checkbox" label="Enabled" />
        </.fieldset>
        <footer class="mt-4 flex justify-end gap-2">
          <.button navigate={return_path(@return_to, @transducer)}>Cancel</.button>
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
    transducer = Transducers.get_transducer!(id)

    socket
    |> assign(:page_title, "Edit transducer")
    |> assign(:transducer, transducer)
    |> assign(:form, to_form(Transducers.change_transducer(transducer)))
  end

  defp apply_action(socket, :new, _params) do
    transducer = %Transducer{}

    socket
    |> assign(:page_title, "New transducer")
    |> assign(:transducer, transducer)
    |> assign(:form, to_form(Transducers.change_transducer(transducer)))
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

    changeset = Transducers.change_transducer(socket.assigns.transducer, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  defp handle_progress(:file, _entry, socket), do: {:noreply, socket}

  defp blank_or("", filename), do: name_from(filename)
  defp blank_or(name, _filename), do: name

  defp name_from(filename) do
    filename |> Path.rootname() |> String.downcase() |> String.replace(~r/[^a-z0-9-]+/, "-")
  end

  @impl true
  def handle_event("validate", %{"transducer" => transducer_params}, socket) do
    changeset = Transducers.change_transducer(socket.assigns.transducer, transducer_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"transducer" => transducer_params}, socket) do
    save_transducer(socket, socket.assigns.live_action, transducer_params)
  end

  defp save_transducer(socket, :edit, transducer_params) do
    case Transducers.update_transducer(socket.assigns.transducer, transducer_params) do
      {:ok, transducer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Saved #{transducer.name}.")
         |> push_navigate(to: return_path(socket.assigns.return_to, transducer))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_transducer(socket, :new, transducer_params) do
    case Transducers.create_transducer(transducer_params) do
      {:ok, transducer} ->
        {:noreply,
         socket
         |> put_flash(:info, "Created #{transducer.name}.")
         |> push_navigate(to: return_path(socket.assigns.return_to, transducer))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _transducer), do: ~p"/admin/transducers"
  defp return_path("show", transducer), do: ~p"/admin/transducers/#{transducer}"
end
