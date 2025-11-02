alias Milo.Repo
alias Milo.Content.Category

categories = [
  %{"name" => "Promotions", "description" => "Deals, offers and promotional emails", "is_default" => true},
  %{"name" => "Newsletters", "description" => "Subscribed newsletters and digests", "is_default" => true},
  %{"name" => "Personal", "description" => "Personal emails from friends and family", "is_default" => true},
  %{"name" => "Finance", "description" => "Banking, bills, invoices and receipts", "is_default" => true},
  %{"name" => "Social", "description" => "Social network notifications and messages", "is_default" => true}
]

for attrs <- categories do
  %Category{}
  |> Category.changeset(attrs)
  |> Repo.insert!(on_conflict: :nothing)
end
