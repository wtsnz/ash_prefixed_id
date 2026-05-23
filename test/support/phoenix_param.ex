unless Code.ensure_loaded?(Phoenix.Param) do
  defprotocol Phoenix.Param do
    @fallback_to_any true
    def to_param(data)
  end

  defimpl Phoenix.Param, for: Any do
    def to_param(%{id: id}), do: to_string(id)
    def to_param(data), do: to_string(data)
  end
end
