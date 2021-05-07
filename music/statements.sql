--The STREAM and TABLE names are prefixed with `ksql_` to enable you to run this demo
--concurrently with the Kafka Streams Music Demo java application, to avoid conflicting names


--The play-events Kafka topic is a feed of song plays, generated by KafkaMusicExampleDriver
CREATE STREAM ksql_playevents WITH (KAFKA_TOPIC='play-events', VALUE_FORMAT='AVRO');

--Filter the play events to only accept events where the duration is >= 30 seconds
CREATE STREAM ksql_playevents_min_duration AS SELECT * FROM ksql_playevents WHERE DURATION > 30000;

--The song-feed Kafka topic contains all of the songs available in the streaming service, generated by KafkaMusicExampleDriver
CREATE TABLE ksql_song (SONG_ID BIGINT PRIMARY KEY) WITH (KAFKA_TOPIC='song-feed', VALUE_FORMAT='AVRO');

--Join the plays with song as we will use it later for charting
CREATE STREAM ksql_songplays AS SELECT plays.SONG_ID AS ID, ALBUM, ARTIST, NAME, GENRE, DURATION FROM ksql_playevents_min_duration plays LEFT JOIN ksql_song songs ON plays.SONG_ID = songs.SONG_ID;

--Track song play counts in 30 second intervals, with a single partition for global view across multiple partitions (https://github.com/confluentinc/ksql/issues/1053)
CREATE TABLE ksql_songplaycounts30 WITH (PARTITIONS=1) AS SELECT ID AS K1, NAME AS K2, GENRE AS K3, AS_VALUE(ID) AS ID, AS_VALUE(NAME) AS NAME, AS_VALUE(GENRE) AS GENRE, COUNT(*) AS COUNT FROM ksql_songplays WINDOW TUMBLING (size 30 second) GROUP BY ID, NAME, GENRE;
--Convert TABLE to STREAM
CREATE STREAM ksql_songplaycounts30stream (ID BIGINT, NAME VARCHAR, GENRE VARCHAR, COUNT BIGINT) WITH (kafka_topic='KSQL_SONGPLAYCOUNTS30', value_format='AVRO');

--Track song play counts for all time, with a single partition for global view across multiple partitions (https://github.com/confluentinc/ksql/issues/1053)
CREATE TABLE ksql_songplaycounts WITH (PARTITIONS=1) AS SELECT ID AS K1, NAME AS K2, GENRE AS K3, AS_VALUE(ID) AS ID, AS_VALUE(NAME) AS NAME, AS_VALUE(GENRE) AS GENRE, COUNT(*) AS COUNT FROM ksql_songplays GROUP BY ID, NAME, GENRE;
--Convert TABLE to STREAM
CREATE STREAM ksql_songplaycountsstream (ID BIGINT, NAME VARCHAR, GENRE VARCHAR, COUNT BIGINT) WITH (kafka_topic='KSQL_SONGPLAYCOUNTS', value_format='AVRO');

--Top Five song counts for all time based on ksql_songplaycountsstream
--At this time, `TOPK` does not support sorting by one column and selecting the value of another column (https://github.com/confluentinc/ksql/issues/403)
--So the results are just counts but not names of the songs associated with the counts
CREATE TABLE ksql_top5 AS SELECT 1 AS KEYCOL, TOPK(COUNT,5) FROM ksql_songplaycountsstream GROUP BY 1;
--Top Five songs for each genre based on each WINDOW of ksql_songplaycounts
CREATE TABLE ksql_top5bygenre AS SELECT GENRE, TOPK(COUNT,5) FROM ksql_songplaycountsstream GROUP BY GENRE;
