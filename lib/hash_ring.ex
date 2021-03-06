defmodule HashRing do
  @compile :native

  @type t :: __MODULE__

  use Bitwise
  alias HashRing.Utils

  defstruct num_replicas: 0, nodes: [], items: {}

  @spec new :: t
  def new, do: new([])

  @spec new([binary], integer) :: t
  def new(nodes, num_replicas \\ 512) do
    rebuild(%__MODULE__{nodes: nodes, num_replicas: num_replicas})
  end

  @spec set_nodes(t, [binary]) :: t
  def set_nodes(ring, nodes) do
    rebuild(%{ring | nodes: nodes})
  end

  @spec add_node(t, binary) :: {:ok, t} | :error
  def add_node(%{nodes: nodes}=ring, name) do
    if name in nodes do
      :error
    else
      {:ok, rebuild(%{ring | nodes: [name|nodes]})}
    end
  end

  @spec remove_node(t, binary) :: {:ok, t} | :error
  def remove_node(%{nodes: nodes}=ring, name) do
    if name in nodes do
      {:ok, rebuild(%{ring | nodes: nodes -- [name]})}
    else
      :error
    end
  end

  @spec find_node(t, binary | integer) :: binary | nil
  def find_node(%{items: items}, key) do
    with {_, name} <- find_next_highest_item(items, Utils.hash(key)) do
      name
    end
  end

  @spec find_nodes(t, binary | integer, integer) :: [binary]
  def find_nodes(%{items: items, nodes: nodes}, key, num) do
    do_find_nodes(items, min(num, length(nodes)), Utils.hash(key), [])
  end

  ## Private

  defp do_find_nodes(_items, 0, _key_int, nodes) do
    Enum.reverse(nodes)
  end
  defp do_find_nodes(items, ret, key_int, nodes) do
    {number, name} = find_next_highest_item(items, key_int)
    if name in nodes do
      do_find_nodes(items, ret, number, nodes)
    else
      do_find_nodes(items, ret - 1, number, [name|nodes])
    end
  end

  defp rebuild(%{nodes: nodes}=ring) do
    %{ring | items: Utils.gen_items(nodes, ring.num_replicas) |> List.to_tuple}
  end

  defp find_next_highest_item(items, key_int) do
    find_next_highest_item(items, tuple_size(items), key_int)
  end

  defp find_next_highest_item(_items, 0, _key_int) do
    nil
  end
  defp find_next_highest_item(items, num_items, key_int) do
    find_next_highest_item(items, num_items, key_int, 0, num_items - 1)
  end

  defp find_next_highest_item(items, num_items, key_int, min, max) do
    mid = div(min + max, 2)
    {number, _name} = elem(items, mid)
    {min, max} =
      if number > key_int do
        # Key is in the lower half.
        {min, mid - 1}
      else
        # Key is in the upper half.
        {mid + 1, max}
      end
    cond do
      min > max and min == num_items ->
        # Past the end of the ring, return the first item.
        elem(items, 0)
      min > max ->
        # Return the next highest item.
        elem(items, min)
      true ->
        find_next_highest_item(items, num_items, key_int, min, max)
    end
  end
end
