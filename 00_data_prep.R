####################
## Author: Stephanie Teeple
## Date: 1 December 2018
## Summary: This file merges NIH ExPORTER 
## project and publication data for upload 
## into IRIS' VDE. 
####################

rm(list = ls())

# libraries
# devtools::install_github("jayhesselberth/nihexporter")
# libraries(nihexporter) #ExPORTER data through 2016
devtools::install_github("ikashnitsky/sjrdata")
library(sjrdata)
library(dplyr)
library(tidyr)


# 1. Download NIH data from ExPORTER and merge each year's files together
# (projects, publications, and the linking tables). Add to list. 

# For many rows, the SCImago variable 'Issn' actually contains two 
# ISSNS - one print and one web version. The order is not consistent 
# (some rows have web first, then print, and vice versa). 
setwd("C:/Users/steeple/Dropbox/EPID_600/final_project_data")

merged <- NULL
pubs <- NULL
link <- NULL
data <- list()
for (i in 2001:2017) {
  
  # Projects
  temp <- tempfile()
  urli <- paste0("https://exporter.nih.gov/CSVs/final/RePORTER_PRJ_C_FY", i, ".zip")
  filenamei <- paste0("RePORTER_PRJ_C_FY", i, ".csv")
  download.file(urli, temp, mode = "wb")
  print(paste("download projects", i))
  unzip(temp, filenamei)
  print(paste("unzip projects", i))
  projects <- read.csv(filenamei, sep = ",", header = TRUE, fill = TRUE, 
                         comment.char = "", colClasses = "character", row.names = NULL)
  projects <- select(projects, ACTIVITY, APPLICATION_ID, BUDGET_START, BUDGET_END, 
                     CORE_PROJECT_NUM, FULL_PROJECT_NUM, FY, ORG_NAME, PI_IDS, 
                     PROJECT_TITLE, STUDY_SECTION_NAME, SUPPORT_YEAR, TOTAL_COST)
  projects <- filter(projects, grepl("R|F|K|T|P", ACTIVITY)) # Filter on the grants you're interested in
  projects$long_PIs <- nchar(projects$PI_IDS) # Exclude projects with more than one PI
  projects <- filter(projects, long_PIs <10)
  projects$missing_cost <- nchar(projects$TOTAL_COST)
  projects <- filter(projects, missing_cost > 0) # Exclude subprojects and projects with missing cost data
  
  # Pubs 
  temp <- tempfile()
  urli <- paste0("https://exporter.nih.gov/CSVs/final/RePORTER_PUB_C_", i, ".zip")
  filenamei <- paste0("RePORTER_PUB_C_", i, ".csv")
  download.file(urli, temp, mode = "wb")
  print(paste("download pubs", i))
  unzip(temp, filenamei)
  print(paste("unzip pubs", i))
  pubs <- read.csv(filenamei, sep = ",", header = TRUE, fill = TRUE, 
                     comment.char = "", colClasses = "character", row.names = NULL)
  pubs$ISSN <- gsub("-", "", pubs$ISSN)
  pubs <- select(pubs, ISSN, JOURNAL_TITLE, PMC_ID, PMID, PUB_DATE, PUB_TITLE, PUB_YEAR)
  
  # Links
  temp <- tempfile()
  urli <- paste0("https://exporter.nih.gov/CSVs/final/RePORTER_PUBLNK_C_", i, ".zip")
  filenamei <- paste0("RePORTER_PUBLNK_C_", i, ".csv")
  download.file(urli, temp, mode = "wb")
  print(paste("download links", i))
  unzip(temp, filenamei)
  print(paste("unzip links", i))
  link <- read.csv(filenamei, sep = ",", header = TRUE, fill = TRUE, 
                     comment.char = "", colClasses = "character", row.names = NULL)
  
  # SCImago
  # TODO: pipe this 
  scimago <- filter(sjr_journals, sjr_journals$year == i)
  scimago <- rename(scimago, impact_factor = cites_doc_2years) 
  scimago <- select(scimago, title, type, issn, impact_factor, year)
  scimago <- separate(scimago, col = issn, into = c("ISSN_1", "ISSN_2"), sep = ", ")
  scimago <- gather(scimago, key = orig_order, value = ISSN, ISSN_1, ISSN_2)
  scimago <- scimago[!is.na(scimago$ISSN),]
                    
  # Merge
  link <- inner_join(pubs, link, by = "PMID")
  link <- inner_join(link, projects, 
                            by = c("PROJECT_NUMBER" = "CORE_PROJECT_NUM"))
  # NOTE - approximately 1/3 of publications do not merge with SCImago data. 
  # ~660,000 of the NIH Exporter pubs don't have an ISSN associated with them. 
  merged[[i]] <- left_join(link, scimago, by = "ISSN")
}

# 2. Rowbind each of the 17 merged files in list 'merged' together. 
data <- bind_rows(merged)
rm(merged)

# NOTE: SCImago does not contain information for 6114 of the 14235 publications
# included in the NIH ExPorter data. The amounts to 1079202 observations of the
# original 3879361. 

