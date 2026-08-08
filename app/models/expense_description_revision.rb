class ExpenseDescriptionRevision < ApplicationRecord
  belongs_to :expense
  belongs_to :actor_user, class_name: "User"

  before_update :prevent_modification
  before_destroy :prevent_modification

  private

  def prevent_modification
    raise ActiveRecord::ReadOnlyRecord, "Expense description revisions are append-only"
  end
end
