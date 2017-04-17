alias SSHServerManager.KeyAuthenticator
alias PublicKeyUtils.Key

defmodule KeyAuthenticator.File do
  @behaviour KeyAuthenticator

  def init(file) do
    with {:ok, stat} <- File.stat(file),
         {:ok, keys} <- load_file(file),
    do: Agent.start_link(fn -> {file, stat, keys} end)
  end

  def is_auth_key(key, _user, agent) do
    Agent.get_and_update(agent, fn({file, stat, keys}) ->
      {stat, keys} =
        case File.stat(file) do
          {:ok, ^stat} -> {stat, keys}
          {:ok, new_stat} ->
            case load_file(file) do
              {:ok, keys} -> {new_stat, keys}
              _ -> {stat, keys}
            end
          _ -> {stat, keys}
        end
      {MapSet.member?(keys, key), {file, stat, keys}}
    end)
  end

  def load_file(file) do
    if file && File.regular?(file) do
      keys =
        File.read!(file)
        |> String.split("\n")
        |> Enum.reduce(MapSet.new, fn(key, keys) ->
          case Key.load(key) do
            {:ok, %{key: key}} ->
              MapSet.put(keys, key)
            _ ->
              keys
          end
        end)
      {:ok, keys}
    else
      {:error, :file_not_found}
    end
  end
end
