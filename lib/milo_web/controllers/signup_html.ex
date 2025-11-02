defmodule MiloWeb.SignupHTML do
  @moduledoc """
  This module contains pages rendered by SignupController.

  See the `signup_html` directory for all templates available.
  """
  use MiloWeb, :html

  embed_templates "signup_html/*"
end
