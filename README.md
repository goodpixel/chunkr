<img alt="Chunkr" width="500px" src="assets/logo_o.svg">

<!-- MDOC !-->

An Elixir keyset-based pagination library for `Ecto`.

## Why Keyset pagination?

The alternative—offset-based pagination—has a couple of serious drawbacks:
* It's inefficient. The further you "page" into the result set, the
  [less efficient your database queries will be](https://use-the-index-luke.com/no-offset) because
  the database has to query for all the results, then count through and discard rows until it
  reaches the desired offset.
* It's inconsistent. Records created or deleted while your user paginates can cause some results
  to either be duplicated or to be entirely missing from what is returned. Depending on your use
  case, this could significantly undermine your user's trust or just be awkward.

Offset-based pagination is generally simpler to implement because, based on the desired page number
and page size, the offset of the next batch can be trivially calculated and incorporated into the
next query.

With keyset-based pagination, rather than tracking how far into the result set you've traversed (and
then hoping records don't change out from under you), we instead track the value of one or more
fields in the first and last record of the batch. Then, to get the next (or previous) batch, we
query with a `WHERE` clause that excludes records up to those values. Not only does the database not
have to pull irrelevant records only to count through them and eventually discard many of them, but
this approach also isn't negatively affected by records being created or removed during
pagination.

All of this makes keyset pagination far more appealing than offset-based pagination.
The gotcha, however, is that it's more troublesome to set up these queries by hand. Fortunately,
we've now made it easy to incorporate keyset pagionation into your Elixir/Ecto apps.
You're going to love it.

For more about the benefits of keyset pagination, see https://use-the-index-luke.com/no-offset.

## What about Cursor-based pagination?

Some people refer to keyset-based pagination as "cursor-based" pagination, which is valid. However,
"cursor" pagination does not necessarily imply keyset pagination since offset pagination can also
be implemented using cursors. Regardless of keyset vs. offset, cursor-based pagination
generally means that the values (either a page number & page size or actual values pulled from a
record) are encoded together into an obfuscated form (e.g. Base64 encoded).

## Use cases

Chunkr can help you implement APIs supporting infinite-scroll style interfaces, [GraphQL pagination](https://graphql.org/learn/pagination/#pagination-and-edges),
pagination per the [Relay spec](https://relay.dev/graphql/connections.htm), REST APIs, etc.

## Installation

Add `chunkr` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:chunkr, "~> 0.1.0"}
  ]
end
```

## Usage

### 1. Set up your pagination strategies…

```elixir
defmodule MyApp.PaginatedQueries do
  use Chunkr.PaginatedQueries

  paginate_by :account_creation_date do
    sort :desc, as(:user).inserted_at
  end

  paginate_by :profile_name do
    sort :asc, fragment("coalesce(?, 'zzzzzzzz')", as(:profile).username)
    sort :asc, fragment("coalesce(?, 'zzzzzzzz')", as(:user).email_address)
    sort :asc, as(:user).id, type: :binary_id
  end
end
```

The `paginate_by/1`  macro sets up a named pagination strategy, and each call to `sort` establishes
a field to sort by when using this strategy. Results will be ordered by the first specified `sort`
clause, with the next clause acting as a tie-breaker, and so on. Note that the final field provided
_must_ be unique in order to provide consistent/deterministic results. Also note that we're
coalescing values. Otherwise, any `NULL` values encountered while filtering against the cursor
will simply be dropped and left out of the paginated result set (SQL cannot reasonably compare
NULL to an actual value using operators like `<` and `>`, so it simply drops them).

You'll notice that we must always use Ecto's `as` clause in order to identify where to find the
field in question. This takes advantage of Ecto's [late bindings](https://hexdocs.pm/ecto/Ecto.Query.html#module-named-bindings)
in referencing a query that is yet to ber established (you could actually use many
different queries with a single pagination strategy defined here so long as each query provides
each of the referenced bindings).

The result of registering these pagination strategies is that at compile-time we automatically
define functions necessary to take a query and extend it for the desired pagination strategy.
This involves dynamically implementing a function to order the results, functions to filter
results against any supplied cursor, and a function to automatically retrieve both the records
themselves as well as all fields necessary to generate the required cursors.

### 2. Add `chunkr` to your `Ecto.Repo`:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres

  use Chunkr, queries: MyApp.PaginatedQueries
end
```

This adds the convenience functions `paginate/3` and `paginate!/3` to your Repo.

### 3. Paginate your queries!

```elixir
query = from u in User, as: :user, join: ap in assoc(u, :account_profile), as: :profile

first_page = MyApp.Repo.paginate!(query, :profile_name, first: 25)

next_page = MyApp.Repo.paginate!(query, :profile_name, first: 25, after: first_page.end_cursor)
```

Here we're using the `:profile_name` pagination strategy established above, and we're providing
all of the named bindings required by that strategy (in this case `:profile_name` and `:user`).

See further documentation at `Chunkr.PaginatedQueries`.

<!-- MDOC !-->

## Documentation

Full documentation is available at [https://hexdocs.pm/chunkr](https://hexdocs.pm/chunkr)
