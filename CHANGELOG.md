# Changelog for v0.x

## 0.3.0 (2023-07)

### Enhancements
  * Set pagination strategy using explicit `:by` opt to `paginate` function. This should be more
    flexible than passing it as the 2nd arg, but it also adds a bit of clarity about what the
    argument represents.
  * Use an optional `inverted: true` opt for `paginate` rather than always passing `:asc` or
    `:desc`. Asc/desc were originally meant to align with the sort direction of the first field
    being sorted on. If the passed direction matched the first sort field's specified direction
    then we used the sort order as specified. Hosever, if it didn’t match, we inverted all of the
    sort directions. This seemed clever, but it ended up being hard to grok. We now invert the
    specified sort orders when `inverted: true` is passed. In any other case, we leave the sort
    directions as specified.

### Removals
  * `Page.total_count` has been removed as it offered little value (total count can be easily
    calculated based on the same query that is passed to Chunkr to be paginated).
