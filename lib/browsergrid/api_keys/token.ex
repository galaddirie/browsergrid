defmodule Browsergrid.ApiKeys.Token do
  @moduledoc """
  Helpers for generating and validating Browsergrid API keys.
  """

  @token_prefix "bg"
  @default_entropy_bytes 32
  @default_prefix_length 4
  @token_regex ~r/^bg_(?<prefix>[A-Za-z0-9]{4,12})_(?<secret>[A-Za-z0-9\-_]{32,128})$/
  @alpha_chars ~c"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  @alpha_chars_length length(@alpha_chars)

  @doc """
  Generate a new API token string and metadata.
  """
  def generate(opts \\ []) do
    entropy = Keyword.get(opts, :entropy_bytes, @default_entropy_bytes)
    prefix_length = Keyword.get(opts, :prefix_length, @default_prefix_length)

    secret =
      entropy
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    prefix = random_prefix(prefix_length)
    token = Enum.join([@token_prefix, prefix, secret], "_")

    %{
      token: token,
      prefix: prefix,
      secret: secret,
      last_four: String.slice(secret, -4, 4)
    }
  end

  @doc """
  Parse a token string into its constituent parts.
  """
  def parse(token) when is_binary(token) do
    case Regex.named_captures(@token_regex, token) do
      %{"prefix" => prefix, "secret" => secret} ->
        last_four = String.slice(secret, -4, 4)

        if String.length(last_four) == 4 do
          {:ok, %{token: token, prefix: prefix, secret: secret, last_four: last_four}}
        else
          {:error, :invalid_token_length}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  def parse(_), do: {:error, :invalid_format}

  @doc """
  Validate if a raw token string is well-formed.
  """
  def valid?(token) when is_binary(token), do: Regex.match?(@token_regex, token)
  def valid?(_), do: false

  defp random_prefix(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> :binary.bin_to_list()
    |> Enum.map(fn byte -> Enum.at(@alpha_chars, rem(byte, @alpha_chars_length)) end)
    |> to_string()
    |> String.slice(0, length)
  end
end
