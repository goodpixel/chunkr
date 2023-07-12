defmodule Chunkr.TestPaginationPlanner do
  @moduledoc false
  use Chunkr.PaginationPlanner

  paginate_by :single_field do
    sort :asc, as(:user).id
  end

  paginate_by :two_fields do
    sort :asc, fragment("coalesce(?, '~~~~~')", as(:user).last_name)
    sort :desc, as(:user).id
  end

  paginate_by :three_fields do
    sort :asc, fragment("coalesce(?, '~~~~~')", as(:user).last_name)
    sort :asc, fragment("coalesce(?, '~~~~~')", as(:user).first_name)
    sort :desc, as(:user).id
  end

  paginate_by :four_fields do
    sort :desc, fragment("coalesce(?, '~~~~~')", as(:user).last_name)
    sort :desc, fragment("coalesce(?, '~~~~~')", as(:user).first_name)
    sort :desc, fragment("coalesce(?, '~~~~~')", as(:user).middle_name)
    sort :asc, as(:user).id
  end

  paginate_by :uuid do
    sort :asc, fragment("coalesce(?, '~~~~~')", as(:user).last_name)
    sort :desc, as(:user).public_id, type: :binary_id
  end

  paginate_by :subquery do
    sort :desc, as(:user).last_name
    sort :asc, as(:user).id
  end

  paginate_by :computed_value do
    sort :desc, as(:user_data).length_of_name
    sort :asc, as(:user).id
  end

  # Contrived example, but this is intended to sort phone numbers by the
  # associated user's name, then by the phone number (minus any non-digits),
  # then by the phone number's ID as a tiebreaker.
  #
  # The essential thing we're looking for here is that phone numbers without an
  # associated user aren't inadvertently dropped from the paginated resut set.
  paginate_by :possibly_null_assoc do
    sort :asc, fragment("coalesce(?, ?)", as(:user).first_name, "~~~~~")
    sort :asc, as(:phone).id
  end
end
