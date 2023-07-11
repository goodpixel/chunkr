<img alt="Chunkr" width="500px" src="assets/logo-o.svg">

Keyset-based query pagination for Elixir and Ecto.

## Use cases

Chunkr helps you implement:

  * pagination for [GraphQL](https://graphql.org/learn/pagination/#pagination-and-edges)
  * pagination per the [Relay spec](https://relay.dev/graphql/connections.htm)
  * paginated REST APIs
  * APIs supporting infinite scroll-style UIs
  * and more…

## Why not Offset-based pagination? 🤔

Offset-based pagination is generally simpler to implement because the offset of the next batch can
be trivially calculated based on the desired page number and page size. However, it has a couple
of significant drawbacks:

  1. **It's inefficient.** The further you "page" into the result set, the
    [less efficient your database queries will be](https://use-the-index-luke.com/no-offset) because
    the database has to query for all applicable results, then count through (and discard rows)
    until the desired offset is reached.

  2. **It's inconsistent.** Records created or deleted while paginating through a result set can
    cause other records to be duplicated or missing from what gets returned. Depending on the use
    case, this could produce invalid results, undermine trust in your application, or just be
    awkward.

## How is Keyset-based better? 😍

With keyset-based pagination, rather than tracking how far into the result set you've traversed (and
then hoping records don't change out from under you), we instead track the value of one or more
fields in the first and last record of the batch. Then, to get the next (or previous) batch, we
query with a `WHERE` clause that excludes records up to those values. With appropriate indexing,
the database does not have to pull irrelevant records (only to count through them and discard
many of them!). Furthermore, this approach isn't negatively affected by records being created
or removed during pagination.

All of this makes keyset pagination far more appealing than offset-based pagination.
The gotcha is that it can be much more troublesome and error-prone to set up the necessary
keyset-based queries by hand. Fortunately, we make it easy to incorporate keyset pagination into
your Elixir/Ecto apps.

One thing keyset-based pagination _cannot_ provide is direct access to an arbitrary "page" of
results. In other words, it's not possible to jump directly from page 2 to page 14—you'd need
offset-based pagation for that. However, that's not necessarily a design pattern we'd encourage
anyway (how is the user to know that the results they want might be on page 14?).

For more about the benefits of keyset pagination, see https://use-the-index-luke.com/no-offset.

## "Keyset" vs. "Cursor" 🧐

Keyset pagination is sometimes referred to as "cursor" pagination, which is valid. However,
not all cursor-based pagination is keyset-based…

In Keyset-based pagination, one or more values from the records being paginated are used to
create a cursor. Then, to paginate past any given cursor, the system must generate a query
that looks for records just beyond the record represented by those cursor values. The cursor
is generally obfuscated (for example, using Base64 encoding) in order to discourage clients
from relying directly on the particular cursor implementation.

Offset-based pagination can also be implemented using cursors. For example, the current
page size and offset can be encoded into an opaque cursor that the system can decode and
use in order to determine what the next or previous page of results would be.

Therefore, Chunkr is indeed cursor-based pagination, but more specificially, it is keyset-based.

## Why Chunkr?

Chunkr took inspiration from both [Paginator](https://github.com/duffelhq/paginator) and
[Quarto](https://github.com/maartenvanvliet/quarto/). However, those libraries had some limitations.

Quarto already addressed the deal-breaking need to reliably sort by columns that might contain
`NULL` values. However, other limitations remained. E.g. it wasn't easy to paginate in reverse
from the end of a result set to the beginning. Also, the existing libraries didn't allow for
sorting by Ecto fragments, which is problematic because it’s often desirable to sort by
calculated values—e.g. to provide case-insensitive sorts of people's names via an Ecto fragment
such as `lower(last_name)`.

### Chunkr provides:
* a simple DSL to establish pagination strategies
* ability to handle `NULL` values (e.g. by using `COALESCE`)
* support for Ecto fragments
* paginating forwards or backwards through a result set
* inversion of pagination strategies
* support for custom encoding of cursor values
* support for custom cursors (e.g. signed cursors)

### Limitations of Chunkr:
* requires Ecto
* pagination strategies must be determined at compiled time
* no more than 4 values per cursor (e.g. you might sort by `last_name`, `first_name`, and
  `middle_name` with `user_id` as the tiebreaker, but you couldn't add a fifth column to sort by
  at this point)
* doesn't yet support custom selection of fields (it always retrieves all fields for the returned
  records)

## Installation

Add `chunkr` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:chunkr, "~> 0.2.1"}
  ]
end
```

## Usage

### 1. Set up your pagination strategies…

```elixir
defmodule MyApp.PaginationPlanner do
  use Chunkr.PaginationPlanner

  paginate_by :username do
    sort :asc, as(:user).username
  end

  paginate_by :user_created_at do
    sort :desc, as(:user).inserted_at
    sort :asc, as(:user).id
  end
end
```

The `Chunkr.PaginationPlanner.paginate_by/2`  macro sets up a named pagination strategy
and automatically implements the necessary supporting functions for that strategy at compile time.

Each call to `sort` establishes a field to sort by when using this strategy. Results
will be ordered by the first specified `sort` clause, with each subsequent clause acting
as a tie-breaker. The final sort field _must_ be unique.

Setting up these pagination strategies enables you to call the paginate function—e.g.
`paginate(some_query, :user_created_at, :desc, opts)` (using the sort direction of the first
`sort` clause). However, you'll also be able to call
`paginate(some_query, :user_created_at, :asc, opts)` and Chunkr will automatically invert all
of the sort orders for you. You always call `paginate()` with the strategy name and the sort
order of the first field, and the rest of the sort orders will flip as needed.

See more docs in the `Chunkr.PaginationPlanner` module.

### 2. Use Chunkr in your Repo module:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use Chunkr, planner: MyApp.PaginationPlanner
end
```

This adds the convenience functions `paginate/4` and `paginate!/4` to your Repo.

### 3. Paginate your queries!

```elixir
# Provide a query implementing all named bindings referenced in your previously-established strategy
iex> query = from u in User, as: :user, join: ap in assoc(u, :account_profile), as: :profile

# Fetch the first page of results using that strategy
iex> first_page = MyApp.Repo.paginate!(query, :username, :asc, first: 25)

# Extract records
iex> records = Chunkr.Page.records(first_page)

# Fetch subsequent pages…
iex> next_page = MyApp.Repo.paginate!(query, :username, :asc, first: 25, after: first_page.end_cursor)
```

See further documentation at `Chunkr.Pagination` and `Chunkr.Page`.

## Documentation

Full documentation is available at [https://hexdocs.pm/chunkr](https://hexdocs.pm/chunkr)
