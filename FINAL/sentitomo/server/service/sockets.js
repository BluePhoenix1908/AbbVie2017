/** @module Sockets */
import fs from 'fs';
import SocketIO from 'socket.io';
import moment from 'moment';
import { convertRawToCsv } from '../util/export';
import { detectTopicLDADynamic, detectTrends } from '../ML/ml_wrapper';
import { Tweet, TweetSentiment, TweetTopic } from '../data/connectors';
import logger from '../service/logger';

/**
 * @function listenToSockets
 * @param  {Object} httpServer Express http server instance
 * @description Start up webserver sockets to allow a bidirectional communication between client and server. 
 * <br />  <strong>Possible events: </strong>
 *      <ul>
 *          <li>client:runTopicDetection - Runs the topic detection method with specified time range, and also joins it with the sentiment from the database, invoked from the client</li>
 *          <li>client:getWorkers- Client requests the status of the topic and sentiment worker threads
 *          <li>client:toggleWorker- Client requests a change of the status of the topic and sentiment worker functions
 *          <li>client:getTrendsForRange Client requests a change of the status of the topic and sentiment worker functions
 *      </ul>
 * @return {void} 
 */
export function listenToSockets(httpServer) {
    var io = new SocketIO(httpServer);
    io.on('connection', function (socket) {

        /*
        * Client requests a dynamic execution of the topic detection.
        * This is independent from the results of topics in the database.
        */
        socket.on('client:runTopicDetection', data => {

            // Send a message to the client, to indicate the process has started
            socket.emit('server:runTopicDetection', {
                level: 'success',
                message: 'Topic detection has started at: ' + new Date(),
                finished: false,
            });

            // Find all tweets in the specified time range
            Tweet.findAll({
                where: {
                    created: {
                        $lt: data.to, // less than
                        $gt: data.from //greater than
                    }
                },
                raw: true //we use raw, we do not need to have access to the sequelize model here
            }).then(tweets => {
                tweets.forEach(function (tweet, index) {
                    tweet.created = moment(tweet.created).format('YYYY-MM-DD hh:mm').toString();
                    tweet.createdAt = moment(tweet.createdAt).format('YYYY-MM-DD hh:mm')
                    tweet.updatedAt = moment(tweet.updatedAt).format('YYYY-MM-DD hh:mm')
                });

                // Convert the tweets to a .csv file, so that it can serve as the input to the python LDA file 
                convertRawToCsv(tweets, './ML/Python/topic/lda/dynamic/tweets.csv')
                    .then(filename => {
                        detectTopicLDADynamic(filename).then(result => {
                            var result = JSON.parse(result.toString().replace("/\r?\n|\r/g", ""))
                            var tweetsIDs = result.map((entry) => { return entry.key })
                            var returnResult = new Object();
                            var returnTweets = new Array();

                            // Enrich the result of the LDA topic detection with data from the database
                            Tweet.findAll({ where: { id: tweetsIDs }, include: [TweetSentiment] }).then(tweets => {

                                tweets.forEach((tweet) => {

                                    var topicTweet = result.find(x => x.key == tweet.id)
                                    returnTweets.push({
                                        id: tweet.id,
                                        message: tweet.message,
                                        hashtags: tweet.hashtags,
                                        topicId: topicTweet.id,
                                        topic: topicTweet.topic,
                                        topicProbability: topicTweet.probability,
                                        created: tweet.created,
                                        sentiment: tweet.TW_Sentiment ? tweet.TW_Sentiment.sentiment : null
                                    });
                                });

                                var topics = new Array();
                                returnTweets.forEach(tweet => {
                                    topics.push({
                                        id: tweet.id,
                                        topicId: tweet.topicId,
                                        topic: tweet.topic,
                                        created: tweet.created,
                                    })
                                })

                                // Same procedure fot the trend detection
                                convertRawToCsv(topics, "./ML/Python/trend/batchTopics.csv").then(filename => {
                                    detectTrends(filename).then(trendResult => {
                                        var trendResult = JSON.parse(trendResult.toString().replace("/\r?\n|\r/g", ""))
                                        returnResult.tweets = returnTweets;
                                        returnResult.trend = trendResult;

                                        // If everything is in place, send the final result back to client so it can be displayed properly
                                        socket.emit('server:runTopicDetection', {
                                            level: 'success',
                                            message: 'Topic detection has finished at: ' + new Date(),
                                            finished: true,
                                            result: returnResult
                                        });
                                    });
                                });
                            });
                        });
                    })
            });
        });

        /*
        * Client requests the current state of the worker threads
        */
        socket.on('client:getWorkers', () => {
            socket.emit('server:getWorkers', {
                topicWorker: global.topicWorker.running,
                sentimentWorker: global.sentimentWorker.running,
            });
        });

        /*
        * Client wants to either stop or start a specific worker thread
        */
        socket.on('client:toggleWorker', data => {
            switch (data.type) {
                case "topic": global.topicWorker.running ? global.topicWorker.stop() : global.topicWorker.start(); break;
                case "sentiment": global.sentimentWorker.running ? global.sentimentWorker.stop() : global.sentimentWorker.start(); break;
                default: break;
            }
        });

        /*
        * The client request a trend detection for a specific date range
        */
        socket.on('client:getTrendsForRange', data => {
            Tweet.findAll({
                where: {
                    created: {
                        $lt: data.to, // less than
                        $gt: data.from//greater than
                    },
                    '$TW_Topic.topicId$': { $ne: null }
                }, include: [{
                    model: TweetTopic, as: TweetTopic.tableName
                }], raw: true
            }).then(tweets => {
                if (tweets.length > 0) {
                    //extract only the data which is needed for the trend detection
                    var exportArray = new Array();
                    tweets.forEach(tweet => {
                        exportArray.push({
                            id: tweet.id,
                            topicId: tweet['TW_Topic.topicId'] ? tweet['TW_Topic.topicId'] : null,
                            created: tweet.created
                        });
                    });

                    /*
                    * Convert the exportArray to a .csv so it can be read by the trendDetection python file
                    * If the trend detection is finished, send the result back to the client
                    */
                    convertRawToCsv(exportArray, "./ML/Python/trend/batchTopics.csv").then(filename => {
                        detectTrends(filename).then(trendResult => {
                            console.log(trendResult);
                            var trendResult = JSON.parse(trendResult.toString().replace("/\r?\n|\r/g", ""))
                            console.log(trendResult);
                            socket.emit('server:getTrendsForRange', {
                                level: 'success',
                                message: 'Trend detection has finished at: ' + new Date(),
                                finished: true,
                                result: trendResult
                            });
                        });
                    });
                } else {
                    socket.emit('server:getTrendsForRange', {
                        level: 'error',
                        message: 'Trend detection failed at: ' + new Date(),
                        finished: true,
                        result: null
                    });
                }

            });
        });
    });
}

