# Shared theme tree fixture for testing
theme_tree_fixture <- list(
  list(
    id = 1,
    name = "Justice and Elections",
    children = list(
      list(
        id = 10,
        name = "Courts",
        icon = "folder",
        children = list(
          list(
            id = 100,
            name = "Crime Statistics",
            icon = "dataflow",
            url = "https://databrowser2.tuik.gov.tr/dataflow/TR,DF_CRIME,1.0"
          ),
          list(
            id = 101,
            name = "Court Database",
            icon = "database",
            url = "https://biruni.tuik.gov.tr/medas/?kn=12&locale=tr"
          ),
          list(
            id = 102,
            name = "Archived XLS",
            icon = "istab",
            url = "/Download/abc123/table.xls"
          ),
          list(
            id = 103,
            name = "Justice Press Release",
            icon = "press",
            url = "/PressRelease/Details/123"
          ),
          list(
            id = 104,
            name = "Justice Annual Report",
            icon = "report",
            url = "/Report/Details/456"
          )
        )
      )
    )
  ),
  list(
    id = 2,
    name = "Population and Demography",
    children = list()
  )
)
