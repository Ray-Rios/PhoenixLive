defmodule PhoenixApp.Repo.Migrations.AlignPagesSchema do
  use Ecto.Migration

  def up do
    rename table(:pages), :template, to: :template_type

    alter table(:pages) do
      add :excerpt, :text
      add :meta_keywords, :string
      add :featured_image, :string
      add :category, :string
      add :order, :integer, default: 0, null: false
      add :published_at, :utc_datetime
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    execute("UPDATE pages SET template_type = 'default' WHERE template_type IS NULL")
    execute("UPDATE pages SET \"order\" = 0 WHERE \"order\" IS NULL")

    create index(:pages, [:author_id])
    create index(:pages, [:category])
    create index(:pages, [:is_published, :order])
  end

  def down do
    drop_if_exists index(:pages, [:is_published, :order])
    drop_if_exists index(:pages, [:category])
    drop_if_exists index(:pages, [:author_id])

    alter table(:pages) do
      remove :author_id
      remove :published_at
      remove :order
      remove :category
      remove :featured_image
      remove :meta_keywords
      remove :excerpt
    end

    rename table(:pages), :template_type, to: :template
  end
end
