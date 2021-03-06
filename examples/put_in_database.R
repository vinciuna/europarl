

library(RMySQL)
library(tidyverse)
#========================


#=================
create_database(dbname = 'epdebate_dev',
                 user = 'epdebate',
                 password = 'slB8EBtmRsuiRbo6',
                 host = '10.1.93.2')

db <- dbConnect(MySQL(),dbname = 'epdebate_dev',
                     user = 'epdebate',
                     password = 'slB8EBtmRsuiRbo6',
                     host = '10.1.93.2',
                encoding = 'utf-8')


dbSendQuery(db,"SET NAMES 'utf8';")

dbGetQuery(db,'
                 SELECT name FROM deputies
                  WHERE id = "124884";
                 ')

dbGetQuery(db, 'SELECT * FROM languages;')

dbSendQuery(db,"SET NAMES 'utf8';")

#dbDisconnect(db)
summary(db)
dbGetInfo(db)

dbListTables(db)
dbListFields(db, 'statements')

for(i in seq_along(deputies)) {
  data <- deputies[[i]]


  data <- data %>%
    select(-2)
  dbWriteTable(db, 'deputies', data,
               append = TRUE, row.names = FALSE)
}


for(i in seq_along(term_of_office_all)) {
  data <- term_of_office_all[[i]]

  dbWriteTable(db, 'term_of_office', data,
               append = TRUE, row.names = FALSE)
}


dbGetQuery(db, 'SELECT id FROM deputies WHERE char_length(id) < 3;')

#name <- deputies_P8$name[1]
#str_replace_all(name,'[:upper:].[:upper:].*', '*')
lang <- get_languages()
languages <- data.frame(
  id=gsub('-.*','',lang),
  full_name=gsub('.*-','',lang),
  stringsAsFactors = FALSE
)

dbWriteTable(db, 'languages', languages,
             append = TRUE, row.names = FALSE)

frakcje <- read.csv("./materials/frakcje.csv", sep=',')

eu_group_code <- data.frame(
  id = frakcje$code,
  full_name = frakcje$group
)

dbWriteTable(db, 'eu_party_code', eu_group_code,
             append=TRUE , row.names = FALSE)

# EU GROUP =============================


load(file = "./data/deputies_info.Rda")

eu_party <- history_of_service$eu_group

tmp <- eu_party %>%
  group_by(deputy_id, date_beginning) %>%
  count() %>%
  filter(n >1)



eu_party_short <- eu_party %>%
  mutate(temp_name = str_replace(name,'.* -',''))

eu_party_short$temp_name <- as.factor(eu_party_short$temp_name)
out <- levels(eu_party_short$temp_name)

out <- c('QQQ', out)
a <- collapse(out, sep ='.*| -')

#str_replace_all(eu_party_short$name[1],a,'')

eu_party_temp <- eu_party %>%
  mutate(full_name = str_replace_all(name,a,''))
levels(eu_party_short$temp_name)

eu_party_temp$full_name <- as.factor(eu_party_temp$full_name)
levels(eu_party_temp$full_name)

eu_party_temp$full_name <- as.factor(str_replace_all(
  eu_party_temp$full_name,'Non-attached Members','Non-attached'))
levels(eu_party_temp$full_name)

eu_party_temp <- eu_party_temp %>%
  mutate(position = str_replace(name,'.* -',''))

eu_party_temp$position <- as.factor(eu_party_temp$position)
levels(eu_party_temp$position)

numbers <- seq(from = 1, to = length(eu_party_temp$deputy_id))
data <- eu_party_temp
eu_temp <- data.frame(
  id = numbers,
  date_beginning = data$date_beginning,
  date_end = data$date_end,
  deputies_id = data$deputy_id,
  position = data$position,
  full_name = data$full_name,
  original_text = data$name
)

dbWriteTable(db, 'eu_party', eu_temp,
             append=TRUE , row.names = FALSE)
# m <- eu_party_temp %>%
#   left_join(eu_group_code, by='full_name')
# ===================================
national_party <- history_of_service$national_party
numbers <- seq(from = 1, to = length(national_party$deputy_id))
temp_national <- data.frame(
  id = numbers,
  full_name = national_party$name,
  date_beginning = national_party$date_beginning,
  date_end = national_party$date_end,
  deputies_id = national_party$deputy_id
)

dbWriteTable(db, 'national_party', temp_national,
             append=TRUE , row.names = FALSE)
rm(temp_national)

# ===================================
directory <- './data/partial_results/'

deputies_P8 <- deputies_P8 %>%
  mutate(row_n = rownames(deputies_P8)) %>%
  select(name, id, row_n)

tmp <- read.csv(paste0(directory,'/8/',"8_1.csv"))

# statements_P8 <- read.table(paste(directory,'8_',deputies_P8$row_n[1],'.txt', sep=''),
#                                encoding ="UTF-8", sep='|', stringsAsFactors = FALSE)
statements_P8 <- read.csv(paste(directory,'/8/','8_',deputies_P8$row_n[1],'.csv', sep=''),
                          stringsAsFactors = FALSE)

statements_P8$text <- gsub('_eol','\n', statements_P8$text)
nazwy <- colnames(statements_P8_pl)




numbers_i <- seq(from = 1, to = length(statements_P8$date))
data <- statements_P8
data$date <- as_date(data$date)
data$startTime <- hms(data$startTime)
data$endTime <- hms(data$endTime)


data$duration <- time_length(data$duration)

data_db <- data.frame(
  id = numbers_i,
  deputies_id = data$deputy_id,
  date = data$date,
  title = data$title,
  reference = data$reference,
  language_code = data$lang_on,
  text = data$text,
  duration = data$duration,
  start_time = data$date + data$startTime,
  end_time = data$date + data$endTime,
  link = data$link,
  term = 8
)
dbWriteTable(db, 'statements', data_db,
             append = TRUE , row.names = FALSE)



for(i in seq_along(deputies_P8$id)) {
  i <- i + 1
  cat(i, '\n')
  if(i == length(deputies_P8$id)) {
    break()
  }
  k <- deputies_P8$row_n[i]

  try_read <- try(data <- read.csv(paste(directory,'/8/','8_',k,'.csv', sep='')))
  if(class(try_read)[1] == 'try-error') {
    cat('error \n')
    tmp_data <- read(paste(direcotry,'8_', k,'.txt', sep=''),
                           encoding ="UTF-8", sep='|', stringsAsFactors = FALSE, quote="")

    for(colname in names(tmp_data)){
      tmp_data[[colname]] <- gsub('\"',"", tmp_data[[colname]])
    }

    #tmp_data[,7] <- gsub('_eol','\n', tmp_data[,7])

    colnames(tmp_data) <- nazwy
    data <- tmp_data
  }

  data$text <- gsub('_eol','\n', data$text)
  cat(k,' ',deputies_P8$name[i] , 'id:',deputies_P8$id[i], '\n')
  #statements_P8_pl <- rbind(statements_P8_pl, data)



  if(nrow(data) != 0) {
    data$date <- as_date(data$date)
    data$startTime <- hms(data$startTime)
    data$endTime <- hms(data$endTime)
    data$duration <- time_length(data$duration)

     data_db <- data.frame(
      deputies_id = data$deputy_id,
      date = data$date,
      title = data$title,
      reference = data$reference,
      language_code = data$lang_on,
      text = data$text,
      duration = data$duration,
      start_time = data$date + data$startTime,
      end_time = data$date + data$endTime,
      link = data$link,
      term = 8
    )

    dbWriteTable(db, 'statements', data_db,
                 append=TRUE , row.names = FALSE)
  }
}


