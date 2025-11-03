defmodule Milo.AI.Categorizer do
  @openai_module Application.compile_env(:milo, :openai_module, OpenAI)

  def categorize_email(body, categories) do
    prompt = """
    Classify this email into one of the following categories:
    #{Enum.join(categories, ", ")}.

    Email content:
    #{body}
    """

    {:ok, resp} =
      openai_module().chat_completion(
        model: "gpt-4o-mini",
        messages: [%{role: "user", content: prompt}]
      )

    resp["choices"]
    |> hd()
    |> get_in(["message", "content"])
    |> String.trim()
  end

  defp openai_module do
    Application.get_env(:milo, :openai_module, @openai_module)
  end
end
