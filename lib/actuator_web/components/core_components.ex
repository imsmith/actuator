defmodule ActuatorWeb.CoreComponents do
  @moduledoc """
  Actuator's own components on top of `GosUi.Components`.

  gos-ui carries the GRID·OPS design system: tokens, the mark sprite, and the
  component markup. What lives here is the Phoenix side it does not take yet: a
  `Phoenix.HTML.FormField`, a LiveView upload, a stream, a navigating link.
  Every class is the system's (`ds-*`) and every value is a token.
  """
  use Phoenix.Component
  use Gettext, backend: ActuatorWeb.Gettext

  import GosUi.Components, only: [mark: 1, modal: 1]

  alias Phoenix.HTML.Form
  alias Phoenix.LiveView.JS

  @doc """
  A button, or a button-styled link when given `navigate`, `href`, or `patch`.
  Variants and sizes are the system's; `danger` is the only control allowed to
  wear `status/critical`.
  """
  attr :variant, :atom, default: :ghost, values: [:primary, :ghost, :text, :danger]
  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :icon, :string, default: nil, doc: "a mark id from the sprite"
  attr :type, :string, default: "button"

  attr :rest, :global,
    include: ~w(href navigate patch method disabled form name value phx-disable-with)

  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :class, [
        "ds-btn",
        "ds-btn--#{assigns.variant}",
        assigns.size != :md && "ds-btn--#{assigns.size}"
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        <.mark :if={@icon} name={@icon} size={16} />
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button type={@type} class={@class} {@rest}>
        <.mark :if={@icon} name={@icon} size={16} />
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  A form field in the system's input anatomy: UPPERCASE label, the control,
  and the error state as border + `m-critical` + message, never color alone.

      <.input field={@form[:name]} label="Name" />
      <.input field={@form[:source]} type="textarea" rows="18" />
      <.input field={@form[:enabled]} type="checkbox" label="Enabled" />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox hidden password select text textarea url)

  attr :field, Phoenix.HTML.FormField, doc: "the form field, for example @form[:email]"
  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, default: [], doc: "options for `Form.options_for_select/2`"

  attr :rest, :global,
    include: ~w(autocomplete disabled placeholder readonly required rows spellcheck)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="ds-field">
      <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
      <label class="ds-check">
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="ds-check__input"
          {@rest}
        />
        <span class="ds-check__box" aria-hidden="true">
          <.mark name="m-low" size={14} class="ds-check__mark" />
        </span>
        <span :if={@label}>{@label}</span>
      </label>
      <.field_errors errors={@errors} />
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class={["ds-field", @errors != [] && "ds-field--error"]}>
      <label :if={@label} class="ds-field__label" for={@id}>{@label}</label>
      <div class="ds-select__wrap">
        <select
          id={@id}
          name={@name}
          class="ds-select"
          aria-invalid={@errors != [] && "true"}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Form.options_for_select(@options, @value)}
        </select>
        <span class="ds-select__chevron"><.mark name="m-chevron" size={16} /></span>
      </div>
      <.field_errors errors={@errors} />
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class={["ds-field", @errors != [] && "ds-field--error"]}>
      <label :if={@label} class="ds-field__label" for={@id}>{@label}</label>
      <div class="ds-field__wrap">
        <textarea
          id={@id}
          name={@name}
          class="ds-input ds-textarea"
          aria-invalid={@errors != [] && "true"}
          {@rest}
        >{Form.normalize_value("textarea", @value)}</textarea>
      </div>
      <.field_errors errors={@errors} />
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class={["ds-field", @errors != [] && "ds-field--error"]}>
      <label :if={@label} class="ds-field__label" for={@id}>{@label}</label>
      <div class="ds-field__wrap">
        <input
          type={@type}
          id={@id}
          name={@name}
          value={Form.normalize_value(@type, @value)}
          class="ds-input"
          aria-invalid={@errors != [] && "true"}
          {@rest}
        />
      </div>
      <.field_errors errors={@errors} />
    </div>
    """
  end

  attr :errors, :list, required: true

  defp field_errors(assigns) do
    ~H"""
    <div :for={msg <- @errors} class="ds-field__msg">
      <.mark name="m-critical" size={12} label="Error" />
      <span>{msg}</span>
    </div>
    """
  end

  @doc """
  The system's file drop around a real `<input type=file>`: a dashed target,
  `m-upload`, a title, and the hint line the system requires. The file is
  uploaded as soon as it is chosen or dropped; the owning LiveView reads it in
  its `:progress` callback.

      <.file_drop upload={@uploads.file} />
  """
  attr :upload, Phoenix.LiveView.UploadConfig, required: true
  attr :label, :string, default: "Drop a file or choose one"
  attr :hint, :string, default: nil, doc: "what is accepted; defaults to the size limit"

  def file_drop(assigns) do
    assigns =
      assign_new(assigns, :hint, fn ->
        "any text file · up to #{div(assigns.upload.max_file_size, 1_000_000)} MB"
      end)

    ~H"""
    <div class="ds-field">
      <label class="ds-drop" id={"#{@upload.ref}-drop"} phx-drop-target={@upload.ref}>
        <.mark name="m-upload" size={24} />
        <span class="ds-drop__title">{@label}</span>
        <span>{@hint}</span>
        <.live_file_input upload={@upload} class="ds-drop__input" />
      </label>
      <ul :if={@upload.entries != []} class="ds-drop__files">
        <li :for={entry <- @upload.entries}>
          <.mark name={if(entry.done?, do: "m-check", else: "m-refresh")} size={12} />
          {entry.client_name}
          <progress :if={!entry.done?} class="ds-progress" value={entry.progress} max="100"></progress>
        </li>
      </ul>
      <.field_errors errors={drop_errors(@upload)} />
    </div>
    """
  end

  defp drop_errors(upload) do
    Enum.map(upload_errors(upload), &upload_error/1) ++
      for entry <- upload.entries,
          err <- upload_errors(upload, entry),
          do: "#{entry.client_name}: #{upload_error(err)}"
  end

  defp upload_error(:too_large), do: "file is too large"
  defp upload_error(:not_accepted), do: "file type is not accepted"
  defp upload_error(:too_many_files), do: "one file at a time"
  defp upload_error(other), do: to_string(other)

  @doc """
  A code block with a head row and a copy button. The copy swaps glyph and
  word for two seconds, never color alone.

      <.code_block id="source" title="cpn-spec 1.0" code={@transducer.source} />
  """
  attr :id, :string, required: true
  attr :title, :string, default: nil
  attr :code, :string, required: true

  def code_block(assigns) do
    ~H"""
    <div class="ds-code" id={@id}>
      <div class="ds-code__head">
        <span>{@title}</span>
        <button
          type="button"
          class="ds-copy"
          id={"#{@id}-copy"}
          phx-hook=".Copy"
          phx-update="ignore"
          data-target={"#{@id}-pre"}
        >
          <.mark name="m-copy" size={14} /><span>copy</span>
        </button>
      </div>
      <pre id={"#{@id}-pre"}>{@code}</pre>
    </div>
    <script :type={Phoenix.LiveView.ColocatedHook} name=".Copy">
      export default {
        mounted() {
          this.el.addEventListener("click", () => {
            const pre = document.getElementById(this.el.dataset.target)
            navigator.clipboard.writeText(pre.innerText).then(() => {
              const word = this.el.querySelector("span")
              const use = this.el.querySelector("use")
              word.textContent = "copied"
              use.setAttribute("href", "#m-check")
              setTimeout(() => {
                word.textContent = "copy"
                use.setAttribute("href", "#m-copy")
              }, 2000)
            })
          })
        }
      }
    </script>
    """
  end

  @doc """
  The page header: an h1, optional actions on the right, optional subtitle.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class="mb-6 flex flex-wrap items-center gap-4">
      <h1 style="font-size:var(--text-h3)">{render_slot(@inner_block)}</h1>
      <div :if={@actions != []} class="ml-auto flex gap-2">{render_slot(@actions)}</div>
      <p
        :if={@subtitle != []}
        class="basis-full"
        style="margin:0;color:var(--muted);font-size:var(--text-small)"
      >
        {render_slot(@subtitle)}
      </p>
    </header>
    """
  end

  @doc """
  An instance's lifecycle state as a chrome tag: glyph + word. Lifecycle is
  not a severity, so this is not the status badge; `<.status_badge>` is for
  health.
  """
  attr :state, :atom, required: true, doc: ":running | :busy | :quiescent | nil"

  def state_tag(assigns) do
    {icon, word} =
      case assigns.state do
        :running -> {"m-run", "running"}
        :busy -> {"m-refresh", "busy"}
        :quiescent -> {"m-check", "quiescent"}
        nil -> {"m-system", "stopped"}
      end

    assigns = assign(assigns, icon: icon, word: word)

    ~H"""
    <span class={["ds-tag", @state in [:running, :busy] && "ds-tag--accent"]} data-role="status">
      <.mark name={@icon} size={12} />
      <span>{@word}</span>
    </span>
    """
  end

  @doc """
  The system's table over a list or a LiveView stream, with a DOM id per row
  and the empty state as one full-width row.

      <.table id="transducers" rows={@streams.transducers}>
        <:col :let={{_id, t}} label="Name">{t.name}</:col>
        <:empty>No transducers.</:empty>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :any, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"
  attr :density, :atom, default: :compact, values: [:comfortable, :compact, :dense]

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"
  slot :empty, doc: "rendered as the only row when there are no rows"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class={["ds-table", @density != :comfortable && "ds-table--#{@density}"]}>
      <thead>
        <tr>
          <th :for={col <- @col} scope="col" class="ds-table__th">{col[:label]}</th>
          <th :if={@action != []} scope="col" class="ds-table__th">
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr
          :for={row <- @rows}
          id={@row_id && @row_id.(row)}
          class={["ds-table__row", @row_click && "ds-table__row--interactive"]}
        >
          <td :for={col <- @col} class="ds-table__td" phx-click={@row_click && @row_click.(row)}>
            {render_slot(col, row)}
          </td>
          <td :if={@action != []} class="ds-table__td" style="width:0;white-space:nowrap">
            <div class="flex gap-2">
              <%= for action <- @action do %>
                {render_slot(action, row)}
              <% end %>
            </div>
          </td>
        </tr>
        <tr :if={@empty != []} id={"#{@id}-empty"} class="hidden only:table-row">
          <td class="ds-table__td ds-table__state" colspan={length(@col) + 1}>
            {render_slot(@empty)}
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  The destructive-confirm flow: names the target, states the consequence and
  irreversibility, and gates the verb button on typing the name. The owner
  handles `confirm-name` (`%{"name" => typed}`), `cancel-delete`, and `delete`.
  """
  attr :name, :string, required: true
  attr :consequence, :string, required: true
  attr :typed, :string, default: ""

  def delete_modal(assigns) do
    ~H"""
    <.modal
      id="delete-modal"
      show
      destructive
      title={"Delete #{@name}?"}
      on_cancel={JS.push("cancel-delete")}
    >
      <p style="margin:0 0 var(--space-2)">{@consequence} This can't be undone.</p>
      <form id="delete-confirm" phx-change="confirm-name" phx-submit="delete">
        <div class="ds-field">
          <label class="ds-field__label" for="delete-confirm-name">Type the name to confirm</label>
          <div class="ds-field__wrap">
            <input
              id="delete-confirm-name"
              name="name"
              value={@typed}
              class="ds-input"
              autocomplete="off"
              placeholder={@name}
            />
          </div>
        </div>
      </form>
      <:footer>
        <.button phx-click="cancel-delete">Cancel</.button>
        <.button
          variant={:danger}
          icon="m-delete"
          type="submit"
          form="delete-confirm"
          disabled={@typed != @name}
        >
          Delete
        </.button>
      </:footer>
    </.modal>
    """
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(ActuatorWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(ActuatorWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
