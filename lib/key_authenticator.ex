defmodule SSHServerManager.KeyAuthenticator do
  @callback init(options) :: {:ok, term()} when options: keyword()
  @callback is_auth_key(key, user, options) :: boolean() when key: PublicKeyUtils.Key.t, user: binary(), options: term()
end
