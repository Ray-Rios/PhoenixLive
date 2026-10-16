defmodule Phxlive.Repo.Migrations.FixCmsOptions do
  use Ecto.Migration

  @moduledoc """
  Makes `cms_options` match `Phxlive.Settings.Option` on every database
  (PHXLIVE.md §13).

  `20250101000005_desktop_and_settings` left two different tables behind:

    * **Built from migrations** (tests, new installs): `id uuid` with no
      default, `key` / `value` / boolean `autoload` / `category`, and no
      `option_name` at all, so every `Phxlive.Settings` call failed. The table
      is rebuilt in the schema's shape; any rows are carried across
      (`key` -> `option_name`, `value` -> `option_value`).
    * **Older databases** (production): the right columns, plus `key` / `value`
      / `category` added by that migration. Nothing reads them, and `key` is
      NOT NULL DEFAULT '' with a unique index, so the second new option ever
      saved failed on `cms_options_key_index`. `key` (it only ever held
      `id::text` or '') and its index are dropped; `value` and `category` are
      dropped only if they hold nothing but their defaults.

  Safe to run on either; a no-op once applied. Not reversible.
  """

  def up do
    execute """
    DO $$
    DECLARE
      in_use boolean;
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema() AND table_name = 'cms_options' AND column_name = 'option_name'
      ) THEN
        CREATE TABLE cms_options_rebuilt (
          id bigserial PRIMARY KEY,
          option_name varchar(255) NOT NULL,
          option_value text NOT NULL DEFAULT '',
          autoload varchar(255) NOT NULL DEFAULT 'yes',
          inserted_at timestamp(0) without time zone NOT NULL,
          updated_at timestamp(0) without time zone NOT NULL
        );

        IF EXISTS (
          SELECT 1 FROM information_schema.tables
          WHERE table_schema = current_schema() AND table_name = 'cms_options'
        ) THEN
          INSERT INTO cms_options_rebuilt (option_name, option_value, autoload, inserted_at, updated_at)
          SELECT key, coalesce(value, ''), CASE WHEN autoload IS FALSE THEN 'no' ELSE 'yes' END,
                 coalesce(inserted_at, now()), coalesce(updated_at, now())
          FROM cms_options
          WHERE coalesce(key, '') <> '';

          DROP TABLE cms_options;
        END IF;

        ALTER TABLE cms_options_rebuilt RENAME TO cms_options;
        ALTER SEQUENCE cms_options_rebuilt_id_seq RENAME TO cms_options_id_seq;
        ALTER INDEX cms_options_rebuilt_pkey RENAME TO cms_options_pkey;
      ELSE
        DROP INDEX IF EXISTS cms_options_key_index;
        ALTER TABLE cms_options DROP COLUMN IF EXISTS key;

        -- Dynamic SQL: these columns may already be gone, and a static
        -- reference would fail when the block is planned.
        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = current_schema() AND table_name = 'cms_options' AND column_name = 'value'
        ) THEN
          EXECUTE 'SELECT EXISTS (SELECT 1 FROM cms_options WHERE value IS NOT NULL)' INTO in_use;
          IF NOT in_use THEN
            ALTER TABLE cms_options DROP COLUMN value;
          END IF;
        END IF;

        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = current_schema() AND table_name = 'cms_options' AND column_name = 'category'
        ) THEN
          EXECUTE 'SELECT EXISTS (SELECT 1 FROM cms_options WHERE coalesce(category, ''general'') <> ''general'')' INTO in_use;
          IF NOT in_use THEN
            DROP INDEX IF EXISTS cms_options_category_index;
            ALTER TABLE cms_options DROP COLUMN category;
          END IF;
        END IF;
      END IF;
    END $$;
    """

    create_if_not_exists unique_index(:cms_options, [:option_name])
    create_if_not_exists index(:cms_options, [:autoload])
  end

  def down, do: :ok
end
