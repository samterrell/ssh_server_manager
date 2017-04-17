# SSHServerManager

Just a simple utility to help you setup SSH for your application.

I wrote this because docker terminal pipes are terrible and crash all the time for me,
and doing a docker terminal to `iex -S mix phoenix.server` or similar to connect into
an IEx on the active app is a pain. Now I just point ssh at it, and everything is
awesome.

Check out http://erlang.org/doc/man/ssh.html

#### Required Stuff
* :ssh app is started (should come with your erlang)
* Have a RSA and/or DSA private key (and maybe others)
* Provide public keys for authentication via the `SSHServerManager.KeyAuthenticator` behavior
  * `KeyAuthenticator.Explicit` lets you pass in an array of public keys
  * `KeyAuthenticator.File` lets you pass in a path to an authroized_keys file
  * Implement your own

#### Configure
Be sure you add `:ssh` to your applications.

Add a worker to your supervision tree like
```elixir
[
  worker(SSHServerManager, [[
    keys: [File.read!("private.rsa"), File.read!("private.dsa")], # Any private key format should work
    key_authenticator: [
      module: SSHServerManager.KeyAuthenticator.Explicit, # Also, .File or your own
      config: [
        "ssh-rsa xxxxxxxxxxx",
        "ssh-dss xxxxxxxxxx"
      ]
    ],
    port: 10022, # default 22, which is only really good for docker
    id_string: "My Awesome Server!", # SSH ID string to client, default to node name
    # shell: :iex, # default
    # shell: :erl,
    # shell: {module, method, args},
    # single_user: false # set to true to only allow one active user
  ]])
]
```
Or manually start it with `SSHServerMangaer.start(keys: ....)`


#### Implement your own authenticator
```elixir
defmodule MyAuth do
  @behaviour SSHServerManager.KeyAuthenticator

  # config from key_authenticator hash goes in
  def init(_config), do: {:ok, nil}

  # result, other than the :ok, goes into the config here
  def is_auth_key(key, _user, _config) do
    user = Accounts.get_ssh_user(key) # or by user name passed in
    if user.has_shell_access do
      Logger.info("#{user.name} logged in via ssh.")
      true
    else
      Logger.warn("#{user.name} tried to login via ssh!")
      false
    end
  end
end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `ssh_server_manager` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:ssh_server_manager, "~> 0.1.0", github: "samterrell/ssh_server_manager"}]
    end
    ```

  2. Ensure `ssh_server_manager` is started before your application:

    ```elixir
    def application do
      [applications: [:ssh, :ssh_server_manager]]
    end
    ```

