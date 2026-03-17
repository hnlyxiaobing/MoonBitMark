///|
test "csv helper counts" {
  inspect(csv_row_count("a,b\n1,2\n"), content="2")
  inspect(csv_column_count("a,b\n1,2\n"), content="2")
}
