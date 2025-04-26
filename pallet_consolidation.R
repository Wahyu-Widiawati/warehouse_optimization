# INIT ENVIRONMENT ############################################
rm(list=ls())
if(!require(readxl)) install.packages('readxl'); library(readxl)
if(!require(DBI)) install.packages('DBI'); library(DBI)
if(!require(RPostgres)) install.packages('RPostgres'); library(RPostgres)
if(!require(reticulate)) install.packages('reticulate'); library(reticulate)
if(!require(tidyverse)) install.packages('tidyverse'); library(tidyverse)
if(!require(stringr)) install.packages('stringr'); library(stringr)
if(!require(lubridate)) install.packages('lubridate'); library(lubridate)

# Set a user-specific library path
user_lib <- "~/R/x86_64-pc-linux-gnu-library/4.0"
.libPaths(user_lib)

# Clean up the environment
rm(list=ls())

# Install and load required packages
packages <- c("readxl", "DBI", "RPostgres", "reticulate", "tidyverse", "stringr", "lubridate")

for (pkg in packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, lib = "~/R/x86_64-pc-linux-gnu-library/4.0" , repos = "https://cloud.r-project.org")
    library(pkg, character.only = TRUE)
  }
}

# DATA CONNECTIONS ############################################
# Connect to Ubuntu postgres
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = "yyy",
  host = "xxx",
  port = 5432,
  user = "postgres",
  password = "zzz"
)

# Setting the schema
dbExecute(con, "SET search_path TO wms_excel")

df <- dbGetQuery(con, "select * from wms_excel.stock_all_fg_location where location_status <> 'On Hold'")

#df$expiry_yyyymm <- ifelse(is.na(df$expiry_date), ifelse(is.na(df$goods_receipt_date), NA, paste0(year(df$goods_receipt_date), month(df$goods_receipt_date))), paste0(year(df$expiry_date), month(df$expiry_date)))
df$expiry_yyyymm <-  paste0(year(df$expiry_date), month(df$expiry_date))

df <- df %>% filter(!is.na(item_code)) %>% 
  group_by(warehouse_site, item_code, item_description, expiry_yyyymm) %>% 
  mutate(n_rows = n()) %>% 
  ungroup() %>% 
  filter(n_rows != 1)

lsdf <- split(df, paste(df$warehouse_site, df$item_code, df$item_description,df$expiry_yyyymm, sep='_'))


# Function to consolidate locations
consolidate_locations <- function(data) {
  
  data <- data %>% filter(physical_soh_box < ctn_pallet,
                          physical_soh_box != 0) %>% 
    select(warehouse_site, location_name, item_code, item_description, expiry_yyyymm, physical_soh_box, ctn_pallet)
  
  if(nrow(data) == 0)
    return('No Consolidation.')
  
  # Sort items by physical_soh_box in descending order
  sorted_data <- data[order(-data$physical_soh_box), ]
  
  locations <- list()
  
  for (i in 1:nrow(data)) {
    placed <- FALSE ### To track if the row/data has been used
    
    for (location in locations) {
      if (sum(location$ctn_pallet) + data[i, "physical_soh_box"] <= location$ctn_pallet) { 
        location <- rbind(location, data[i, ])
        locations[[which(locations == location)]] <- location
        placed <- TRUE
        break
      }
    }
    
    if (!placed) {
      locations <- c(locations, list(data.frame(warehouse_site = data[i, 'warehouse_site'],
                                                location_name = data[i, "location_name"],
                                                item_code = data[i, "item_code"],
                                                item_description = data[i, "item_description"],
                                                expiry_yyyymm = data[i, "expiry_yyyymm"],
                                                physical_soh_box = data[i, "physical_soh_box"],
                                                ctn_pallet = data[i, "ctn_pallet"])))
    }
  }
  
  # Consolidate locations
  consolidated <- TRUE
  while (consolidated) {
    consolidated <- FALSE
    for (i in seq_along(locations)) {
      for (j in (i + 1):length(locations)) {
        if(j>length(locations))
          next
        if (sum(locations[[i]]$physical_soh_box) + sum(locations[[j]]$physical_soh_box) <= mean(locations[[i]]$ctn_pallet)) {
          locations[[i]] <- rbind(locations[[i]], locations[[j]])
          locations <- locations[-j]
          consolidated <- TRUE
          break
        }
      }
      if (consolidated) break
    }
  }
  
  return(locations)
}

dfFinal_2 <- data.frame()
for(p in 1:length(lsdf)) {
  
  # Consolidate locations
  consolidated_locations <- consolidate_locations(lsdf[[p]])
  
  if(length(consolidated_locations)==0) {
    next
  }
  if(class(consolidated_locations) != 'list') {
    next
  }
  
  
  # Print consolidated locations
  if(length(consolidated_locations) != nrow(lsdf[[p]])) {
    
    n <-1
    for (i in seq_along(consolidated_locations)) {
      if(nrow(consolidated_locations[[i]]) > 1) {
        cat('Warehouse, Product, expiry month: ', names(lsdf[p]), '\n')
        cat("Location", n, ":", paste(consolidated_locations[[i]]$location_name, collapse = ", "), "\n\n")
        
        #dfFinal_2 <- bind_rows(dfFinal_2, data.frame(product_expiry = names(lsdf[p]),
        #                                         location_number = n,
        #                                         consolidate_locations = paste(consolidated_locations[[i]]$location_name, collapse = ", ")))
        
        # Iterate over each consolidated location list
        for (i in seq_along(consolidated_locations)) {
          # Check if the current consolidated location list has more than one location
          if (nrow(consolidated_locations[[i]]) > 1) {
            # Create a data frame for the current consolidated locations
            consolidated_df <- data.frame(product_expiry = names(lsdf[p]),
                                          location_number = n,
                                          location_name = consolidated_locations[[i]]$location_name,
                                          physical_soh_box = consolidated_locations[[i]]$physical_soh_box,
                                          ctn_pallet = consolidated_locations[[i]]$ctn_pallet)
            # Append the data frame to dfFinal_2
            dfFinal_2 <- bind_rows(dfFinal_2, consolidated_df)
            
            # Increment the location number
            n <- n + 1
          }
        }
        
        
        
        n<-n+1
      }
    }
  }
}

dfFinal_2 <- dfFinal_2 %>% mutate(warehouse_site = sapply(str_split(product_expiry, '_'), '[[', 1),
                              item_code = sapply(str_split(product_expiry, '_'), '[[', 2),
                              item_description = sapply(str_split(product_expiry, '_'), '[[', 3),
                              expiry_month = sapply(str_split(product_expiry, '_'), '[[', 4)) %>% 
  filter(!grepl('NANA', product_expiry))

### Add To Location Column
dfFinal_2 <- dfFinal_2 %>%
  group_by(product_expiry, location_number) %>%
  mutate(to_location = location_name[which.max(physical_soh_box)]) %>%
  ungroup()

### Remove rows where to location = location name
dfFinal_2 <- dfFinal_2 %>%
filter(to_location != location_name)

### Change location_name to be From Location 
dfFinal_2 <- dfFinal_2 %>%
rename(`from_location` = 'location_name')

dfFinal_2$last_updated <- Sys.time()

##### Data Validation
dfFinal_2_check <- dfFinal_2 %>% select (-location_number) %>%
                  unique() %>%
                  group_by(product_expiry, from_location, physical_soh_box, ctn_pallet, warehouse_site, item_code, item_description, expiry_month,to_location) %>%
                  mutate(n_rows = n()) %>%
                  select(product_expiry, warehouse_site, item_code,item_description, expiry_month, from_location, to_location, physical_soh_box, ctn_pallet, last_updated)

dbWriteTable(con, 'stock_fg_honeycomb', dfFinal_2_check, overwrite=T)
print("Wrote successfully to stock_fg_honeycomb")
 
