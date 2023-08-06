defmodule SvgPathOffsetRemover do
  @moduledoc """
  Documentation for `SvgPathOffsetRemover`.
  """

  @type arguments() :: %{
    svg_content: binary(),
    output_file_path: binary() | nil
  }

  @path_coords_regex ~r/[ML]([-+]?\d*\.\d+|[-+]?\d+) ([-+]?\d*\.\d+|[-+]?\d+)|V([-+]?\d*\.\d+|[-+]?\d+)/
  @type coords :: %{
    x: number(),
    y: number()
  }

  def start(_, _) do
    with {:ok, args} <- parse_args() do
      root_element = :fxml_stream.parse_element(args.svg_content)
      children = get_svg_children(root_element)

      case children do
        {:ok, children} ->
          coords_offset = get_path_nodes_coords_offset(children)

          new_children = update_path_nodes_coords(children, coords_offset)
          new_svg_content = :fxml.element_to_binary(put_elem(root_element, 3, new_children))

          if args.output_file_path == nil do
            IO.puts(new_svg_content)
          else
            File.write!(args.output_file_path, new_svg_content)
          end

          :ok

        :error ->
          :error
      end
    end

  end

  @spec get_path_nodes_coords_offset(list()) :: coords()
  def get_path_nodes_coords_offset(nodes) do
    Enum.flat_map(nodes, fn
      {:xmlel, "path", attrs, _children} ->
        get_coords_from_attrs(attrs)

      _ ->
        []
    end)
    # |> IO.inspect(label: "All nodes attributes")
    |> Enum.reduce(%{x: Float.max_finite(), y: Float.max_finite()}, fn coords, acc ->
      acc
      |> update_coords_offset(coords, :x)
      |> update_coords_offset(coords, :y)
    end)
  end

  @spec update_coords_offset(coords(), coords(), :x | :y) :: coords()
  def update_coords_offset(coords_offset, coords, axis) do
    if coords_offset[axis] > coords[axis] do
      %{coords_offset | axis => coords[axis]}
    else
      coords_offset
    end
  end

  @spec get_coords_from_attrs(list()) :: [coords()]
  def get_coords_from_attrs(attrs) do
    for {"d", value} <- attrs do
      matches = Regex.scan(@path_coords_regex, value)
      Enum.map(matches, &case &1 do
        [<<cmd, _::binary>>, x, y] when cmd in ~C(M L) ->
          %{x: String.to_float(x), y: String.to_float(y)}

        ["V" <> _, "", "", y] ->
          %{x: Float.max_finite, y: String.to_float(y)}
      end)
    end
    |> Enum.flat_map(& &1)
  end

  @spec update_path_nodes_coords(list(), coords()) :: list
  def update_path_nodes_coords(nodes, coords_offset) do
    Enum.map(nodes, fn
      {:xmlel, "path", attrs, children} ->
        attrs = remove_offset_from_attrs(attrs, coords_offset)

        {:xmlel, "path", attrs, children}

      node ->
        node
    end)
  end

  @spec remove_offset_from_attrs(list(), coords()) :: list()
  def remove_offset_from_attrs(attrs, coords_offset) do
    Enum.map(attrs, fn
      {"d", value} ->
        new_value =
          Regex.scan(@path_coords_regex, value)
          |> Enum.map(&case &1 do
            [<<cmd, _::binary>>, x, y] when cmd in ~C(M L) ->
              [cmd, remove_offset_from_value(x, coords_offset.x), " ", remove_offset_from_value(y, coords_offset.y)]

            ["V" <> _, "", "", y] ->
              ["V", to_string(String.to_float(y) - coords_offset.y)]
          end)
          # |> Enum.intersperse(" ")
          |> IO.iodata_to_binary()

        {"d", new_value}

      attr ->
        attr
    end)
  end

  @spec remove_offset_from_value(binary(), number()) :: binary()
  def remove_offset_from_value(value, offset) do
    to_string(String.to_float(value) - offset)
  end

  def get_svg_children({:xmlel, "svg", _attrs, children}) do
    {:ok, children} # |> IO.inspect(label: "SVG children")
  end

  def get_svg_children({:error, reason}) do
    IO.puts("Could not parse XML: #{inspect reason}")

    :error
  end

  def get_svg_children({:xmlcdata, value}) do
    IO.puts("Cannot get children of CDATA: #{inspect value}")

    :error
  end

  @spec parse_args :: {:error, binary()} | {:ok, arguments()}
  def parse_args() do
    arguments = %{
      svg_content: "",
      output_file_path: nil
    }

    {switch_opts, opts, _} = OptionParser.parse(System.argv(), strict: [content: :string, save_path: :string])

    with {:ok, arguments} <- parse_svg_input_opt(arguments, switch_opts, opts),
         arguments <- %{arguments | output_file_path: switch_opts[:save_path]} do
      {:ok, arguments}
    end
  end

  def parse_svg_input_opt(arguments, switch_opts, opts) do
    cond do
      is_nil(switch_opts[:content]) and opts == [] ->
        {:error, "Missing argument (either --content or file path directly)"}

      File.regular?(Enum.at(opts, 0)) ->
        {:ok, %{arguments | svg_content: File.read!(Enum.at(opts, 0))}}

      true ->
        {:ok, %{arguments | svg_content: switch_opts[:content]}}
    end
  end
end
