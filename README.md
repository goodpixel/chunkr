<img alt="Chunkr" width="500px" src="assets/logo_o.svg">

<!-- MDOC !-->

Keyset-based query pagination for Elixir and Ecto.

## Use cases

Chunkr helps you implement:

  * pagination for [GraphQL](https://graphql.org/learn/pagination/#pagination-and-edges)
  * pagination per the [Relay spec](https://relay.dev/graphql/connections.htm)
  * paginated REST APIs
  * APIs supporting infinite scroll-style UIs
  * and more…

## Why Keyset pagination? 😍

The alternative—offset-based pagination—has a couple of serious drawbacks:

  1. It's inefficient. The further you "page" into the result set, the
    [less efficient your database queries will be](https://use-the-index-luke.com/no-offset) because
    the database has to query for all the results, then count through and discard rows until it
    reaches the desired offset.

  2. It's inconsistent. Records created or deleted while your user paginates can cause some results
    to either be duplicated or to be entirely missing from what is returned. Depending on your use
    case, this could significantly undermine your user's trust or just be awkward.

Offset-based pagination is generally simpler to implement because, based on the desired page number
and page size, the offset of the next batch can be trivially calculated and incorporated into the
next query.

With keyset-based pagination, rather than tracking how far into the result set you've traversed (and
then hoping records don't change out from under you), we instead track the value of one or more
fields in the first and last record of the batch. Then, to get the next (or previous) batch, we
query with a `WHERE` clause that excludes records up to those values. Not only does the database not
have to pull irrelevant records only to count through them and discard many of them, but
this approach also isn't negatively affected by records being created or removed during
pagination.

All of this makes keyset pagination far more appealing than offset-based pagination.
The gotcha is that it can be much more troublesome and error-prone to set up the necessary
keyset-based queries by hand. Fortunately, we've now made it easy to incorporate keyset
pagination into your Elixir/Ecto apps. You're going to love it.

One thing keyset-based pagination _cannot_ provide is direct access to an arbitrary "page" of
results. In other words, it's not possible to jump directly from page 2 to page 14—you'd need
offset-based pagation for that. However, that's not necessarily a design pattern we'd encourage
anyway (how is the user to know that the results they want might be on page 14?). Rather than
jumping to an arbitrary page of results, Chunkr allows you to jump to an arbitrary position in
the results based on actual sort values. For example, when sorting records alphabetically,
you could allow the user to jump directly to records starting with the letter "R".
See Chunkr's `:from` option for examples.

For more about the benefits of keyset pagination, see https://use-the-index-luke.com/no-offset.

## What about Cursor-based pagination? 🤔

Keyset pagination is sometimes referred to as "cursor-based" pagination, which is valid. However,
keyset pagination is not the only type of pagination that can be implemented with cursors.

In Keyset-based pagination, one or more values from the records being paginated are used to
create a cursor. Then, to paginate past any given cursor, the system must generate a query
that looks for records just beyond the record represented by those cursor values. The cursor
is generally obfuscated (for example, using Base64 encoding) in order to discourage clients
from relying directly on the particular cursor implementation.

As previously mentioned, "cursor-based" pagination does not necessarily imply "keyset" pagination;
offset-based pagination can also be implemented using cursors. For example, the current
page size and offset can be encoded into an opaque cursor that the system can decode and
use in order to determine what the next or previous page of results would be.

Therefore, Chunkr is indeed cursor-based pagination. But more specificially, it is keyset-based.

## Why Chunkr?

Chunkr took inspiration from both [Paginator](https://github.com/duffelhq/paginator) and
[Quarto](https://github.com/maartenvanvliet/quarto/). However, those libraries had some limitations.

Quarto already addressed the deal-breaking need to reliably sort by columns that might contain
`NULL` values. However, other limitations remained. E.g. it wasn't easy to paginate in reverse
from the end of a result set to the beginning. Also, pagination was broken when sorting by fields on
associations that might be missing (say, for example, sorting users by their preferred
address—specifically when not all users have specified a "preferred" address). Furthermore, the
existing libraries didn't allow for sorting by Ecto fragments, which is problematic because it’s
often desirable to sort by calculated values—e.g. to provide case-insensitive sorts of people's
names via an Ecto fragment such as `lower(last_name)`.

Chunkr:
* provides a simple DSL to declare your pagination strategies
* implements the necessary supporting functions for your pagination strategies at compile time
* automatically implements inverse sorts for you
* enables paginating forwards or backwards through a result set
* enables jumping directly to a specific value in a result set using the `:from` option
* honors Ecto fragments

## Installation

Add `chunkr` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:chunkr, "~> 0.2.0"}
  ]
end
```

## Usage

### 1. Set up your pagination strategies…

```elixir
defmodule MyApp.PaginationPlanner do
  use Chunkr.PaginationPlanner

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

The `Chunkr.PaginationPlanner.paginate_by/2`  macro sets up a named pagination strategy,
and each call to `sort` establishes a field to sort by when using this strategy. Results
will be ordered by the first specified `sort` clause, with the next clause acting as a
tie-breaker, and so on. Note that the final field provided _must_ be unique in order
to provide consistent/deterministic results. Also note that we're coalescing values.
Otherwise, any `NULL` values encountered while filtering against the cursor will simply
be dropped and left out of the paginated result set (SQL cannot reasonably compare
NULL to an actual value using operators like `<` and `>`, so it simply drops them).

You'll notice that we must always use Ecto's `as` clause in order to identify where to find the
field in question. This takes advantage of Ecto's [late bindings](https://hexdocs.pm/ecto/Ecto.Query.html#module-named-bindings)
in referencing a query that is yet to be established (you can use many
different queries with a single pagination strategy defined here so long as each query provides
each of the referenced bindings).

The result of registering these pagination strategies is that at compile time we automatically
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

  use Chunkr, planner: MyApp.PaginationPlanner
end
```

This adds the convenience functions `paginate/4` and `paginate!/4` to your Repo.

### 3. Paginate your queries!

```elixir
query = from u in User, as: :user, join: ap in assoc(u, :account_profile), as: :profile

first_page = MyApp.Repo.paginate!(query, :profile_name, first: 25)

next_page = MyApp.Repo.paginate!(query, :profile_name, first: 25, after: first_page.end_cursor)
```

Here we're using the `:profile_name` pagination strategy established above, and we're providing
all of the named bindings required by that strategy (in this case `:profile` and `:user`).

See further documentation at `Chunkr.PaginatedQueries`.

<!-- MDOC !-->

## Documentation

Full documentation is available at [https://hexdocs.pm/chunkr](https://hexdocs.pm/chunkr)
