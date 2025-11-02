defmodule MiloWeb.OnboardingHTML do
  @moduledoc """
  This module contains pages rendered by OnboardingController.

  See the `onboarding_html` directory for all templates available.
  """
  use MiloWeb, :html

  embed_templates "onboarding_html/*"
end
