# Chunkr

<!-- MDOC !-->

An Elixir keyset-based pagination library for `Ecto`.

## Why not offset-based pagination?

Offset-based pagination has a couple of serious drawbacks:
* **It's inefficient.** The further you "page" into the result set, the
  [less efficient your database queries will be](https://use-the-index-luke.com/no-offset).
* **It's inconsistent.** Records being created or deleted while your user paginates through results
  can cause your user to end up seeing duplicated results—or having results be just inadvertently
  dropped. Depending on the use case, this could significantly impact your user's trust.

Offset-based pagination is traditionally "easier" because, based on the desired page and page size,
you can easily calculate how many records to skip and provide that to the database as part of your
query. However, given the drawbacks, it's not a desirable form of pagination when User Experience
is of interest.

Keyset-based pagination is more troublesome to figure out from scratch, but we've made it simple
to get going. We think you're going to love it.

As a side note, some people refer to keyset-based pagination as "cursor-based" pagination, which…it
is. However, offset-based pagination can also be implemented using opaque cursors, and therefore,
cursor-based pagination doesn't necessarily mean it's keyset-based.

For more about the benefits of keyset-based pagination, see https://use-the-index-luke.com/no-offset.

## Use cases

Chunkr can help you implement APIs supporting "infinite-scroll" style interfaces, GraphQL pagination
[as suggested by the GraphQL folks](https://graphql.org/learn/pagination/#pagination-and-edges),
[Relay-style pagination](https://relay.dev/graphql/connections.htm), REST APIs, etc.

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

1. Set up your pagination strategies:

    ```elixir
    defmodule MyApp.PaginatedQueries do
      use Chunkr.PaginatedQueries

      paginate_by :account_creation_date do
        sort :desc, as(:user).inserted_at
      end

      paginate_by :profile_name do
        sort :asc, fragment("lower(coalesce(?, 'zzzzzzzz'))", as(:profile).username)
        sort :asc, fragment("lower(coalesce(?, 'zzzzzzzz'))", as(:user).email_address)
        sort :asc, as(:user).id, type: :binary_id
      end
    end
    ```

2. Add `chunkr` to your `Ecto.Repo`:

    ```elixir
    defmodule MyApp.Repo do
      use Ecto.Repo,
        otp_app: :my_app,
        adapter: Ecto.Adapters.Postgres

      use Chunkr, queries: MyApp.PaginatedQueries
    end
    ```

3. Paginate some queries!!

    ```elixir
    query = from u in User, as: :user, join: p in assoc(u, :phone_numbers), as: :profile
    MyApp.Repo.paginate(query, :profile_name, first: 25)
    ```



See `Chunkr.PaginatedQueries` for more.

<!-- MDOC !-->

## Documentation

Full documentation is available at [https://hexdocs.pm/chunkr](https://hexdocs.pm/chunkr)
