alias PublicKeyUtils.Key
import Record

defmodule SSHServerManager do
  use GenServer

  defrecordp :state, [
    port: nil,
    keys: nil,
    key_authenticator: nil,
    key_authenticator_config: nil,
    id_string: nil,
    pid: nil,
    single_user: nil,
    shell: nil
  ]

  def start(options) do
    with {:ok, state} <- get_state(options),
    do: GenServer.start(__MODULE__, state)
  end

  def start_link(options) do
    with {:ok, state} <- get_state(options),
    do: GenServer.start_link(__MODULE__, state)
  end

  defp get_state(options) do
    with {:ok, key_authenticator, key_authenticator_config} <- get_key_authenticator(options[:key_authenticator]),
         {:ok, port} <- get_port(options[:port]),
         {:ok, keys} <- get_keys(options[:keys]),
         {:ok, id_string} <- get_id_string(options[:id_string]),
         {:ok, single_user} <- get_single_user(options[:single_user]),
         {:ok, shell} <- get_shell(options[:shell]) do
      {:ok, state(
        port: port,
        keys: keys,
        key_authenticator: key_authenticator,
        key_authenticator_config: key_authenticator_config,
        single_user: single_user,
        id_string: id_string,
        shell: shell
      )}
    end
  end

  defp get_port(nil), do: {:ok, 22}
  defp get_port(int) when is_integer(int), do: {:ok, int}
  defp get_port(str) when is_binary(str) do
    case Integer.parse(str) do
      {int, ""} -> {:ok, int}
      _ -> {:error, :invalid_port}
    end
  end

  defp get_shell(nil), do: get_shell(:iex)
  defp get_shell(:iex), do: {:ok, {IEx, :start, []}}
  defp get_shell(:erl), do: {:ok, {:shell, :start, []}}
  defp get_shell({_, _, _} = shell), do: {:ok, shell}

  defp get_key_authenticator(options) do
    case {options[:module], options[:config] || []} do
      {nil, _} ->
        {:error, :missing_key_authenticator}
      {module, config} when is_atom(module) ->
        with {:ok, state} <- module.init(config),
        do: {:ok, module, state}
      _ ->
        {:error, :invalid_key_authenticator}
    end
  end

  def init(state() = state) do
    case start_daemon(state) do
      {:ok, pid} -> {:ok, state(state, pid: pid)}
      bad -> {:stop, bad}
    end
  end

  def host_key(algorithm, options) do
    options
    |> Keyword.get(:key_cb_private, [])
    |> Keyword.get(:manager)
    |> GenServer.call({:get_server_key, algorithm})
  end
  def is_auth_key(key, user, options) do
    options
    |> Keyword.get(:key_cb_private, [])
    |> Keyword.get(:manager)
    |> GenServer.call({:is_auth_key, key, user})
  end

  defp start_daemon(state(port: port, single_user: single_user, id_string: id_string, shell: shell)) do
    :ssh.daemon(port,
      auth_methods: 'publickey',
      subsystems: [],
      shell: shell,
      parallel_login: !single_user,
      id_string: to_charlist(id_string),
      key_cb: {__MODULE__, manager: self()}
    )
    |> case do
      {:ok, pid} ->
        if Process.link(pid) do
          {:ok, pid}
        else
          {:error, :could_not_link}
        end
      ssh_err ->
        {:error, ssh_err}
    end
  end

  defp get_keys(nil), do: {:error, :no_server_keys}
  defp get_keys(list) when is_list(list) do
    keys =
      Enum.reduce(list, %{}, fn(key, keys) ->
        case Key.load(key) do
          {:ok, %{private: true, algorithm: alg} = key} ->
            Map.put(keys, alg, key)
          _ ->
            keys
        end
      end)
    if keys == %{} do
      {:error, :no_keys}
    else
      {:ok, keys}
    end
  end

  defp get_id_string(nil), do: {:ok, to_string(Node.self)}
  defp get_id_string(str) when is_binary(str), do: {:ok, str}
  defp get_id_string(_), do: {:error, :invalid_id_string}

  defp get_single_user(nil), do: {:ok, false}
  defp get_single_user(bool) when is_boolean(bool), do: {:ok, bool}
  defp get_single_user(_), do: {:error, :invalid_value_for_single_user}

  def handle_call({:get_server_key, :"ssh-dss"}, _from, state(keys: %{dsa: %{key: key}}) = state) do
    {:reply, {:ok, key}, state}
  end
  def handle_call({:get_server_key, :"ssh-rsa"}, _from, state(keys: %{rsa: %{key: key}}) = state) do
    {:reply, {:ok, key}, state}
  end
  def handle_call({:get_server_key, _}, _from, state) do
    {:reply, {:error, :key_not_found}, state}
  end

  def handle_call({:is_auth_key, key, user}, _from, state(key_authenticator: km, key_authenticator_config: kmc) = state) do
    {:reply, km.is_auth_key(key, user, kmc), state}
  end

  def handle_cast(:stop, state(pid: pid)) do
    :ssh.stop_daemon(pid)
    {:stop, :user_request, nil}
  end
end
