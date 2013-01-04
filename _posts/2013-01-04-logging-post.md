
---
layout: post
title: "Configuring Spark Logs"
author: "Imran"
tags:
  - Spark
---

After you run a few Spark jobs, you'll realize that Spark spits out a lot of logging messages.  At first, we found
this too distracting, so we turned off all Spark logs.  But that was too heavy-handed -- we always wanted to see a some
of the log messages, and of course, when we needed to debug something, we wanted everything.

<!--more-->

So, we settled on the following configuration for log4j:

    # make a file appender and a console appender
    # Print the date in ISO 8601 format
    log4j.appender.myConsoleAppender=org.apache.log4j.ConsoleAppender
    log4j.appender.myConsoleAppender.layout=org.apache.log4j.PatternLayout
    log4j.appender.myConsoleAppender.layout.ConversionPattern=%d [%t] %-5p %c - %m%n
    log4j.appender.myFileAppender=org.apache.log4j.RollingFileAppender
    log4j.appender.myFileAppender.File=spark.log
    log4j.appender.myFileAppender.layout=org.apache.log4j.PatternLayout
    log4j.appender.myFileAppender.layout.ConversionPattern=%d [%t] %-5p %c - %m%n



    # By default, everything goes to console and file
    log4j.rootLogger=INFO, myConsoleAppender, myFileAppender

    # The noisier spark logs go to file only
    log4j.logger.spark.storage=INFO, myFileAppender
    log4j.additivity.spark.storage=false
    log4j.logger.spark.scheduler=INFO, myFileAppender
    log4j.additivity.spark.scheduler=false
    log4j.logger.spark.CacheTracker=INFO, myFileAppender
    log4j.additivity.spark.CacheTracker=false
    log4j.logger.spark.CacheTrackerActor=INFO, myFileAppender
    log4j.additivity.spark.CacheTrackerActor=false
    log4j.logger.spark.MapOutputTrackerActor=INFO, myFileAppender
    log4j.additivity.spark.MapOutputTrackerActor=false
    log4j.logger.spark.MapOutputTracker=INFO, myFileAppender
    log4j.additivty.spark.MapOutputTracker=false


This configuration file sends all the logs (from Spark and everything else) to a file.  That way we have the full logs
if we need to debug later on.  In addition, we log everything to the console except for some spark messages
that are a little too verbose.  But, we keep some of the logs from Spark on the console.  In particular, starting
with [Spark 0.6](http://spark-project.org/release-0.6.0.html), the logs include a message telling you when its running a
job, and exactly where in your code it got triggered:

    2012-11-01 13:00:10,647 [main] INFO  spark.SparkContext - Starting job: aggregate at MyAwesomeSourceFile.scala:86
    2012-11-01 13:00:25,169 [main] INFO  spark.SparkContext - Job finished: aggregate at MyAwesomeSourceFile.scala:86, took 14.521604475 s

To make use of this configuration, first save it into a text file. Then if you add it to your classpath, it will automatically get picked up.
In particular, with Spark you can just drop it in the "conf" directory, as that is already on the classpath by default.  Or, you can configure
it via code with:

     import org.apache.log4j.PropertyConfigurator;
     PropertyConfigurator.configure(propertyFile)

We should add that even though we're sending most of the spark logs to a file, those log messages are *great*.  There is
all sorts of great information in there -- how many partitions are being used, the size of the serialized tasks, which
nodes they are running on, progress as individual tasks finish, etc.  They are invaluable for more detailed debugging
and optimization.  Sometimes we even watch the full logs as the job is running with `tail -f spark.log`.

There are a few log messages that only make it into the file, that we really wish we could also get in the console. Eg.,
sub-stages of a job get logged with DAGScheduler:

    2012-10-31 13:54:00,757 [DAGScheduler] INFO  spark.scheduler.DAGScheduler - Submitting Stage 1 (map at MyAwesomeSourceFile.scala:57), which has no missing parents
    2012-10-31 13:54:00,785 [DAGScheduler] INFO  spark.scheduler.DAGScheduler - Submitting 52 missing tasks from Stage 1
    ...
    2012-10-31 13:58:45,215 [DAGScheduler] INFO  spark.scheduler.DAGScheduler - Stage 1 (map at MyAwesomeSourceFile.scala:57) finished; looking for newly runnable stages
    2012-10-31 13:58:45,216 [DAGScheduler] INFO  spark.scheduler.DAGScheduler - running: Set(Stage 2)
    2012-10-31 13:58:45,217 [DAGScheduler] INFO  spark.scheduler.DAGScheduler - waiting: Set(Stage 0)
    2012-10-31 13:58:45,217 [DAGScheduler] INFO  spark.scheduler.DAGScheduler - failed: Set()

However, DAGScheduler emits so many more log messages, that we'd rather just have these messages in the file.  Maybe in
the future Spark will move those messages to another class, so they're easy to filter from the rest of the messages? :)


We know that there isn't one "right way" to configure your logging, but we hope this is at least a useful starting point
for others.  Let us know if you come up with any useful variants of this, or even if you decide on a completely different
setup.
