defmodule Mix.Phoenix do
  # Conveniences for Phoenix tasks.
  @moduledoc false

  @doc """
  Copies files from source dir to target dir
  according to the given map.

  Files are evaluated against EEx according to
  the given binding.
  """
  def copy_from(apps, source_dir, target_dir, binding, mapping) when is_list(mapping) do
    roots = Enum.map(apps, &Application.app_dir(&1, source_dir))

    for {format, source_file_path, target_file_path} <- mapping do
      source =
        Enum.find_value(roots, fn root ->
          source = Path.join(root, source_file_path)
          if File.exists?(source), do: source
        end) || raise "could not find #{source_file_path} in any of the sources"

      target = Path.join(target_dir, target_file_path)

      contents =
        case format do
          :text -> File.read!(source)
          :eex  -> EEx.eval_file(source, binding)
        end

      Mix.Generator.create_file(target, contents)
    end
  end

  @doc """
  Inflect path, scope, alias and more from the given name.

      iex> Mix.Phoenix.inflect("user")
      [alias: "User",
       human: "User",
       base: "Phoenix",
       module: "Phoenix.User",
       scoped: "User",
       singular: "user",
       path: "user"]

      iex> Mix.Phoenix.inflect("Admin.User")
      [alias: "User",
       human: "User",
       base: "Phoenix",
       module: "Phoenix.Admin.User",
       scoped: "Admin.User",
       singular: "user",
       path: "admin/user"]

      iex> Mix.Phoenix.inflect("Admin.SuperUser")
      [alias: "SuperUser",
       human: "Super user",
       base: "Phoenix",
       module: "Phoenix.Admin.SuperUser",
       scoped: "Admin.SuperUser",
       singular: "super_user",
       path: "admin/super_user"]
  """
  def inflect(singular) do
    base     = Mix.Phoenix.base
    scoped   = Phoenix.Naming.camelize(singular)
    path     = Phoenix.Naming.underscore(scoped)
    singular = String.split(path, "/") |> List.last
    module   = Module.concat(base, scoped) |> inspect
    alias    = String.split(module, ".") |> List.last
    human    = Phoenix.Naming.humanize(singular)

    [alias: alias,
     human: human,
     base: base,
     module: module,
     scoped: scoped,
     singular: singular,
     path: path]
  end

  @doc """
  Parses the attrs as received by generators.
  """
  def attrs(attrs) do
    Enum.map attrs, fn attr ->
      case String.split(attr, ":", parts: 3) do
        [key, comp, value] -> {String.to_atom(key), {String.to_atom(comp), String.to_atom(value)}}
        [key, value]       -> {String.to_atom(key), String.to_atom(value)}
        [key]              -> {String.to_atom(key), :string}
      end
    end
  end

  @doc """
  Generates some sample params based on the parsed attributes.
  """
  def params(attrs) do
    attrs
    |> Enum.reject(fn
        {_, {:references, _}} -> true
        {_, _} -> false
       end)
    |> Enum.into(%{}, fn
        {k, {:array, _}}      -> {k, []}
        {k, :integer}         -> {k, 42}
        {k, :float}           -> {k, "120.5"}
        {k, :decimal}         -> {k, "120.5"}
        {k, :boolean}         -> {k, true}
        {k, :map}             -> {k, %{}}
        {k, :text}            -> {k, "some content"}
        {k, :date}            -> {k, %{year: 2010, month: 4, day: 17}}
        {k, :time}            -> {k, %{hour: 14, min: 0}}
        {k, :datetime}        -> {k, %{year: 2010, month: 4, day: 17, hour: 14, min: 0}}
        {k, :uuid}            -> {k, "7488a646-e31f-11e4-aace-600308960662"}
        {k, _}                -> {k, "some content"}
    end)
  end

  @doc """
  Checks the availability of a given module name.
  """
  def check_module_name_availability!(name) do
    name = Module.concat(Elixir, name)
    if Code.ensure_loaded?(name) do
      Mix.raise "Module name #{inspect name} is already taken, please choose another name"
    end
  end

  @doc """
  Returns the module base name based on the configuration value.

      config :my_app
        app_namespace: My.App

  """
  def base do
    app = Mix.Project.config |> Keyword.fetch!(:app)

    case Application.get_env(app, :app_namespace, app) do
      ^app -> app |> to_string |> Phoenix.Naming.camelize
      mod  -> mod |> inspect
    end
  end

  @doc """
  Returns all compiled modules in a project.
  """
  def modules do
    Mix.Project.compile_path
    |> Path.join("*.beam")
    |> Path.wildcard
    |> Enum.map(&beam_to_module/1)
  end

  defp beam_to_module(path) do
    path |> Path.basename(".beam") |> String.to_atom()
  end
end
