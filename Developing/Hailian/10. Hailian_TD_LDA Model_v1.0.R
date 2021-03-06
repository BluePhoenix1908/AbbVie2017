devtools::install_github("cpsievert/LDAvisData")
data(Reviews, package = "LDAvisData")

url <- "http://cran.us.r-project.org/src/contrib/Archive/cldr/cldr_1.1.0.tar.gz"
pkgFile<-"cldr_1.1.0.tar.gz"
download.file(url = url, destfile = pkgFile)
install.packages(pkgs=pkgFile, type = "source", repos = NULL)
unlink(pkgFile)

install.packages("lda")
install.packages("LDAvis")
install.packages("servr")

library(tm)
library(lda)
library(LDAvis)
library(servr)
library(text2vec)
library(cldr)

#read file by navigation
Final_TW_Newest<- read.csv(file.choose(),encoding = "UTF-8")
###get key, tweets, time of TW dataset
Final_TW_Tweets<- Final_TW_Newest[c(1,9,2)]
Final_TW_Tweets<- data.frame(na.omit(Final_TW_Tweets))
colnames(Final_TW_Tweets)<- c("key", "Text","time")

#remove non-english posts
Final_TW_Tweets_lag<- detectLanguage(Final_TW_Tweets[[2]])
Final_TW_Tweets<- cbind(Final_TW_Tweets,Final_TW_Tweets_lag)
Final_TW_Tweets<- subset(Final_TW_Tweets,detectedLanguage=="ENGLISH")[c(1,2,3)]




# read in some stopwords:

stop_words <- stopwords("SMART")

#deeper clean
clean <- function (sentence){
  #convert to lower-case 
  sentence <- tolower(sentence)
  removeURL <- function(x) gsub('"(http.*) |(https.*) |(http.*)$|\n|can|just|do|now|will|get|one|dont|also|much|really|even|use|got|still|year|cant|new|going|since|every|want|by|about|as|so|it|may|â|ã|ãƒâ|šã|å|ãƒæ|iãƒæ|rt|ed|fc|bd|bc', "", x)
  sentence <- removeURL(sentence)
}

# pre-processing:
Final_TW_Tweets$Text <- sapply(Final_TW_Tweets$Text, function(x) clean(x))
Final_TW_Tweets$Text <- removeNumbers(Final_TW_Tweets$Text)
Final_TW_Tweets$Text <- lemmatize_strings(Final_TW_Tweets$Text)
Final_TW_Tweets$Text <- removeWords(Final_TW_Tweets$Text, stop_words)
Final_TW_Tweets$Text <- gsub("'", "", Final_TW_Tweets$Text)  # remove apostrophes
Final_TW_Tweets$Text <- gsub("[[:punct:]]", " ", Final_TW_Tweets$Text)  # replace punctuation with space
Final_TW_Tweets$Text <- gsub("[[:cntrl:]]", " ", Final_TW_Tweets$Text)  # replace control characters with space
Final_TW_Tweets$Text <- gsub("^[[:space:]]+", "", Final_TW_Tweets$Text) # remove whitespace at beginning of documents
Final_TW_Tweets$Text <- gsub("[[:space:]]+$", "", Final_TW_Tweets$Text) # remove whitespace at end of documents



# tokenize on space and output as a list:
doc.list <- strsplit(Final_TW_Tweets$Text, "[[:space:]]+")

# compute the table of terms:
term.table <- table(unlist(doc.list))
term.table <- sort(term.table, decreasing = TRUE)

#termtable<- as.data.frame(term.table)

# remove terms that are stop words or occur fewer than 5 times:
del <- names(term.table) %in% stop_words | term.table < 200
term.table <- term.table[!del]
vocab <- names(term.table)

# now put the documents into the format required by the lda package:
get.terms <- function(x) {
  index <- match(x, vocab)
  index <- index[!is.na(index)]
  rbind(as.integer(index - 1), as.integer(rep(1, length(index))))
}
documents <- lapply(doc.list, get.terms)

# Compute some statistics related to the data set:
D <- length(documents)  # number of documents
W <- length(vocab)  # number of terms in the vocab 
doc.length <- sapply(documents, function(x) sum(x[2, ]))  # number of tokens per document 
N <- sum(doc.length)  # total number of tokens in the data
term.frequency <- as.integer(term.table)  # frequencies of terms in the corpus

# MCMC and model tuning parameters:
K <- 20
G <- 100
alpha <- 0.02
eta <- 0.02

# Fit the model:
#set.seed(357)
t1 <- Sys.time()
fit <- lda.collapsed.gibbs.sampler(documents = documents, K = K, vocab = vocab, 
                                   num.iterations = G, alpha = alpha, 
                                   eta = eta, initial = NULL, burnin = 0,
                                   compute.log.likelihood = TRUE)
t2 <- Sys.time()
t2 - t1  # about 2 minutes on laptop

theta <- t(apply(fit$document_sums + alpha, 2, function(x) x/sum(x)))
phi <- t(apply(t(fit$topics) + eta, 2, function(x) x/sum(x)))
datasetReviews <- list(phi = phi,
                     theta = theta,
                     doc.length = doc.length,
                     vocab = vocab,
                     term.frequency = term.frequency)


# create the JSON object to feed the visualization:
json <- createJSON(phi = datasetReviews$phi, 
                   theta = datasetReviews$theta, 
                   doc.length = datasetReviews$doc.length, 
                   vocab = datasetReviews$vocab, 
                   term.frequency = datasetReviews$term.frequency)


serVis(json, out.dir = 'viii', open.browser = TRUE)

