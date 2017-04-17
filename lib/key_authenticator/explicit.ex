alias SSHServerManager.KeyAuthenticator
alias PublicKeyUtils.Key

defmodule KeyAuthenticator.Explicit do
  @behaviour KeyAuthenticator

  def init(nil), do: {:error, :no_authorized_keys}
  def init(list) when is_list(list) do
    keys =
      Enum.reduce(list, MapSet.new, fn(key, keys) ->
        case Key.load(key) do
          {:ok, key} -> MapSet.put(keys, key.key)
          _ -> keys
        end
      end)
    if MapSet.size(keys) == 0 do
      {:error, :no_authorized_keys}
    else
      {:ok, keys}
    end
  end
  def init(key) do
    with {:ok, key} <- Key.load(key),
    do: {:ok, MapSet.new([key.key])}
  end

  def is_auth_key(key, _user, keys) do
    MapSet.member?(keys, key)
  end
end
