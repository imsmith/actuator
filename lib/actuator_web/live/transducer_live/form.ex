defmodule ActuatorWeb.TransducerLive.Form do
  use ActuatorWeb, :live_view

  alias Actuator.Transducers
  alias Actuator.Transducers.Transducer

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>
          Source is a <code>cpn-spec 1.0</code> net. It is parsed and validated on every keystroke.
        </:subtitle>
      </.header>

      <.form for={@form} id="transducer-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input
          field={@form[:source]}
          type="textarea"
          label="Source"
          rows="18"
          class="textarea font-mono text-sm w-full"
        />
        <.input field={@form[:entry_place]} type="text" label="Entry place" />
        <.input field={@form[:enabled]} type="checkbox" label="Enabled" />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Transducer</.button>
          <.button navigate={return_path(@return_to, @transducer)}>Cancel</.button>
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
    transducer = Transducers.get_transducer!(id)

    socket
    |> assign(:page_title, "Edit Transducer")
    |> assign(:transducer, transducer)
    |> assign(:form, to_form(Transducers.change_transducer(transducer)))
  end

  defp apply_action(socket, :new, _params) do
    transducer = %Transducer{}

    socket
    |> assign(:page_title, "New Transducer")
    |> assign(:transducer, transducer)
    |> assign(:form, to_form(Transducers.change_transducer(transducer)))
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
         |> put_flash(:info, "Transducer updated successfully")
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
         |> put_flash(:info, "Transducer created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, transducer))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _transducer), do: ~p"/admin/transducers"
  defp return_path("show", transducer), do: ~p"/admin/transducers/#{transducer}"
end
