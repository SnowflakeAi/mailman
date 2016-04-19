defmodule Mailman.Render do
  @moduledoc "Functions for rendering email messages into strings"

  @doc "Returns a tuple with all data needed for the underlying adapter to send"
  def render(email) do
    compile_parts(email)
    |> to_tuple(email)
    |> :mimemail.encode
  end

  def to_tuple({:mixed, parts}, email) when is_list(parts) do
    {
      "multipart",
      "mixed",
      headers_for(email),
      [],
      Enum.map(parts, &to_tuple(&1, email))
    }
  end
  
  def to_tuple({:alternative, parts}, email) when is_list(parts) do
    {
      "multipart",
      "alternative",
      [],
      [],
      Enum.map(parts, &to_tuple(&1, email))
    }
  end
  
  def to_tuple({:related, parts}, email) when is_list(parts) do
    {
      "multipart",
      "related",
      [],
      [],
      Enum.map(parts, &to_tuple(&1, email))
    }
  end
  
  def to_tuple(part, _email) when is_tuple(part) do
    {
      mime_type_for(part),
      mime_subtype_for(part),
      [],
      parameters_for(part),
      elem(part, 1)
    }
  end

  def to_tuple([], email) do
    {}
  end

  def to_tuple(parts, email) when is_list(parts) do
    IO.puts "LIST"
    {
      mime_type_for(parts),
      mime_subtype_for(parts),
      [],
      [],
      Enum.map(parts, &to_tuple(&1, email))
    }
  end

  def parameters_for({:attachment, _body, attachment}) do
    [
      { "transfer-encoding", "base64" },
      content_type_params_for(attachment),
      disposition_for(:attachment, attachment),
      disposition_params_for(:attachment, attachment)
    ]
  end

  def parameters_for({:related_attachment, _body, attachment}) do
    [
      content_id_for(attachment),
      { "transfer-encoding", "base64" },
      content_type_params_for(attachment),
      disposition_for(:related_attachment, attachment),
      disposition_params_for(:related_attachment, attachment)
    ]
  end

  def parameters_for(_part) do
    [
      { "transfer-encoding", "quoted-printable" },
      { "content-type-params", [] },
      { "disposition", "inline" },
      { "disposition-params", [] }
    ]
  end

  def content_id_for(attachment) do
    { "content-id", "<" <> attachment.file_name <> ">" }
  end
  
  def content_type_params_for(_attachment) do
    { "content-type-params", [] }
  end

  def disposition_for(:related_attachment, attachment) do
    { "disposition", "inline" }
  end

  def disposition_for(_, _attachment) do
    { "disposition", "attachment" }
  end

  def disposition_params_for(_, attachment) do
    { "disposition-params", [{ "filename", attachment.file_name }] }
  end

  def mime_type_for(parts) when is_list(parts) do
    "multipart"
  end

  def mime_type_for({_type, _}) do
    "text"
  end

  def mime_type_for({_, _, attachment}) do
    attachment.mime_type
  end

  def mime_subtype_for(parts) when is_list(parts) do
    "mixed"
  end

  def mime_subtype_for({type, _}) do
    type
  end

  def mime_subtype_for({_, _, attachment}) do
    attachment.mime_sub_type
  end

  def headers_for(email) do
    [
      { "From", email.from },
      { "To", email.to |> normalize_addresses |> Enum.join(",") },
      { "Subject", email.subject },
      { "reply-to", email.reply_to },
      { "Cc",  email.cc |> as_list |> normalize_addresses |> Enum.join(", ") |> as_list },
      { "Bcc", email.bcc |> as_list |> normalize_addresses |> Enum.join(", ") |> as_list }
    ] |> Enum.filter(fn(i) -> elem(i, 1) != [] end)
  end

  def as_list(value) when is_list(value) do
    value
  end

  def as_list("") do
    []
  end

  def as_list(value) when is_binary(value) do
    [ value ]
  end

  def normalize_addresses(addresses) when is_list(addresses) do
    addresses |> Enum.map(fn(address) ->
      case address |> String.split("<") |> Enum.count > 1 do
        true -> address
        false ->
          name = address |>
            String.split("@") |>
            List.first |>
            String.split(~r/([^\w\s]|_)/) |>
            Enum.map(&String.capitalize/1) |>
            Enum.join(" ")
          "#{name} <#{address}>"
      end
    end)
  end

  def compile_parts(email) do
    attachments = Enum.map(email.attachments, fn(attachment) ->
      { :attachment, attachment.data, attachment }
    end)
    related_attachments = Enum.map(email.related_attachments, fn(attachment) ->
      { :related_attachment, attachment.data, attachment }
    end)

    { :mixed, [
        { :related, [
            { :alternative, [
                { :plain, email.text },
                { :html,  email.html }
              ]},
          ] ++ related_attachments
        }
      ] ++ attachments
    }
  end

  @doc "Returns boolean saying if a value for a tuple is blank as a string or list"
  def not_empty_tuple_value(tuple) when is_tuple(tuple) do
    value = elem(tuple, 1)
    value != nil && value != [] && value != ""
  end

  def not_empty_tuple_value([]) do
    false
  end

  def not_empty_tuple_value(tuple) when is_list(tuple) do
    true
  end

  def not_empty_tuple_value(t) do
    IO.inspect t
    false
  end

end
