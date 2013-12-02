---
layout: post
title: "Guaranteed Message Delivery with Kafka"
author: "Imran"
tags:
  - Kafka
---

[Kafka](https://kafka.apache.org/) is a distributed message queuing system with "strong durability and fault-tolerance guarantees".  Under normal use,
consumers are guaranteed to see messages _at least once_.  However, as we'll see, unless applications are extremely careful, messages can easily get dropped
when the application fails.

<!--more-->

In this post, we'll first explain how messages can get dropped, and then introduce our solution to the problem, that we've made into an [open-source](https://github.com/quantifind/kafka-utils) wrapper around
the kafka consumer api.

# Dropped Messages with a Basic Kafka Consumer

First of all, lets be clear: we are *not* claiming there are any faults within kafka itself.  We still believe that kafka guarantees _at least once_ semantics.
But that doesn't necessarily mean that your *application* gets to see the messages at least once.  How is that possible?  Lets consider a very simple kafka consumer
that reads from a kafka stream `itr`:

    while(itr.hasNext) {
      val msg = itr.next()
      doSomething(msg)      //this is where your application processes the msg
    }

That's about as simple as it can get -- and yet this application might skip some messages.  Suppose that your application dies after a message was pulled off
the kafka queue by `itr.next()`, but before the message gets processed in `doSomething(msg)`.  When you restart your application, kafka will think that it has
pulled the message off the queue, so it won't deliver it to your application again.

We'll admit, this isn't that likely.  It won't happen unless kafka also happens to *commit* the offsets between the call to `itr.next()` and `doSomething(msg)` --
by default, this happens in a background thread, once every minute.  But this is still undesirable and a real pain to fix, and as we'll see, the problem is even worse with batch
processing.

# Dropped Messages with Batch Processing

Many kafka applications will buffer a number of messages, and then process them together in a batch.  For example, consider this simple app that will write messages
into a database.  The threads that are reading data from kafka will simply add them to a buffer:

    while(itr.hasNext) {
      val msg = itr.next()
      buffer.synchronized {
        buffer += msg
      }
    }

And another thread will periodically write the contents of that buffer into a database:

    buffer.synchronized {
      writeBufferToDB(buffer)
      buffer.clear()
    }

Apps will usually want to buffer a lot of messages, and do a big batch insert into the database.  But now we've made the *message dropping* problem much worse.  Anytime the application
dies, it's extremely likely that kafka has already committed all the messages that were sitting in the buffer, but haven't been inserted into the database yet.

The problem in both cases is the same: kafka thinks it has lived up to the _at least once_ guarantee as soon as it has delivered the message to your app.  But we want something
stronger.  We want to know that our app *finishes* processing each message at least once.  That means we've got to control when kafka commits messages as being fully
processed, so that we can tell it when we're done.

# Guaranteeing Your App Sees All Messages

We can write our consumers to ensure that each message is processed by our app at least once.  The bad news is, the code gets quite a bit more complicated.  The good news is,
we've already written it, and we're open sourcing our [kafka utils library](https://github.com/quantifind/kafka-utils).

Lets take a look at how you would use our library to buffer a series of messages from kafka, and do a batch insert into a db.  First, you need to write a worker that
puts messages into a buffer, and can return that buffer on demand.

    class MessageBufferingWorker
       extends BatchConsumerWorker[String,String,Seq[String]] {
      var buffer = Vector[String]()
      def addMessageToBatch(msg: MessageAndMetadata[String,String]) {buffer :+= msg.message}
      def getBatch() = {
        val b = buffer
        buffer = Vector[String]()
        b
      }
    }

Second, you need to write another class that will receive a group of those buffers (possibly from many independent workers), merge them together, and insert into a database

    class InsertCountersInPostgres(val db: Connection) 
        extends BatchMerger[String] {
      val insertStmt = db.prepareStatement("insert into my_table values (?)")
      def handleBatch(batch: Iterator[Seq[String]]) = {
        val allMsgs = batch.toSeq.flatten
        db.setAutoCommit(false)
        for (msg <- allMsgs) {
          insertStmt.setString(1,msg)
          insertStmt.addBatch()
        }
        insertStmt.executeBatch()
        db.commit()
      }
    }

By just defining these two simple classes, we can read from kafka with multiple threads, periodically bulk insert messages into a db, and we're guaranteed that
all messages get inserted into our database at least once.  The library takes care of coordinating work among all the threads, and knowing when to commit progress
to kafka.

It's worth noting that to do this properly, with the existing kafka api, you'd need to halt *all* threads that are reading from kafka.  That is because the kafka
api only lets you commit progress for all threads simultaneously.  But this library gets around that issue, by going beneath the public api, and using a feature
that will be introduced in kafka 0.8.1: [committing offsets for one partition at a time](https://issues.apache.org/jira/browse/KAFKA-1144).

So, by using our kafka-consumer library, you:

1. Guarantee _at least once_ processing of all messages by your application.
2. Avoid blocking all threads during a commit, increasing throughput. 
3. Save yourself the hassle of coordinating all worker threads, tracking the progress through the message queues, and committing progress yourself.

# Why Not Exactly Once?

How come we're going through all this work for just _at least once_?  Don't we actually want _exactly once_?  Or maybe none of this matters, and we should just live
with the fact that some messages can get dropped.

While we'd all love _exactly once_, that's [hard to do in general](https://kafka.apache.org/documentation.html#semantics) while still [getting high throughput](http://java.dzone.com/articles/akeaways-kafka-talk-airbnb).  If we have a system that guarantees _at least once_, then we can often build an _exactly once_ system on top.  

For that matter, even when we're building an _at least once_ system, we are really saying "we *guarantee* all messages will be seen at least once, but we're going to
_try hard_ to make sure most messages get processed exactly once."  Our library won't ever commit progress to kafka ahead of where our app is, but it
also makes sure that it commits progress as soon as each batch is fully processed, to ensure that most messages only get processed once.

Many systems might not even care about the problems we've discovered with the _at least once_ guarantee.  After all, the problem only occurs when your application
dies.  So if you've got a rock-solid application that never dies, then you're fine.

But, we like relying on kafka as a key distributed, fault-tolerant part of our stack.  Which means that sometime we can get away with writing simple, non-distributed apps,
that might die if something goes wrong with their host; but they'll just pick up from kafka again when they restart.  Plus,
we've found these guarantees especially important when developing an app.  As we do test deployments, apps get started and stopped a lot, and as we're testing out
new code, inevitably we trigger some exceptions in our code.  Its nice to know that we're still guaranteed all messages
were processed, despite any restarts.

# Notes

We got lots of help from the [kafka user list](http://mail-archives.apache.org/mod_mbox/kafka-users/) while discovering the problem and figuring out a fix. 
We hope that open-sourcing our solution to the problem is our way
of giving back to the community.  Also, we're hoping the community will continue to improve on our solution   (Pull requests always welcome!).  We'd love to add an
api for _exactly once_ processing, and also some tools for monitoring the progress of your kafka consumers.  Hopefully something
similar will even make it into the standard api with kafka 0.9, [currently scheduled for release next April](https://cwiki.apache.org/confluence/display/KAFKA/Future+release+plan).
