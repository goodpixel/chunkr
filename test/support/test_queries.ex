defmodule Chunkr.TestQueries do
  use Chunkr.PaginatedQueries

  paginate_by :single_field do
    sort :asc, as(:user).id
  end

  paginate_by :two_fields do
    sort :asc, fragment("lower(coalesce(?, ?))", as(:user).last_name, "zzz")
    sort :desc, as(:user).id
  end

  paginate_by :three_fields do
    sort :asc, fragment("lower(coalesce(?, ?))", as(:user).last_name, "zzz")
    sort :asc, fragment("lower(coalesce(?, ?))", as(:user).first_name, "zzz")
    sort :desc, as(:user).id
  end

  paginate_by :four_fields do
    sort :desc, fragment("lower(coalesce(?, ?))", as(:user).last_name, "zzz")
    sort :desc, fragment("lower(coalesce(?, ?))", as(:user).first_name, "zzz")
    sort :desc, fragment("lower(coalesce(?, ?))", as(:user).middle_name, "zzz")
    sort :asc, as(:user).id
  end

  paginate_by :uuid do
    sort :asc, fragment("lower(coalesce(?, ?))", as(:user).last_name, "zzz")
    sort :desc, as(:user).public_id, type: :binary_id
  end

  paginate_by :subquery do
    sort :desc, fragment("coalesce(?, now() - interval '2000 years')", as(:phones).created_at)
    sort :asc, as(:user).id
  end

  # Contrived example, but this is intended to sort phone numbers by the
  # associated user's name, then by the phone number (minus any non-digits),
  # then by the phone number's ID as a tiebreaker.
  #
  # The essential thing we're looking for here is that phone numbers without an
  # associated user aren't inadvertently dropped from the paginated resut set.
  paginate_by :by_possibly_null_association do
    sort :asc, fragment("lower(coalesce(?, ?))", as(:user).last_name, "zzz")
    sort :asc, fragment("lower(coalesce(?, ?))", as(:user).first_name, "zzz")

    sort :asc,
         fragment(
           "coalesce(regexp_replace(?, '[^0-9]+', '', 'g'), ?)",
           as(:phone).number,
           "999999999999999"
         )

    sort :asc, as(:phone).id
  end
end
