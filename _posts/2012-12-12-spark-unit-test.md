
---
layout: post
title: "Unit Testing With Spark"
---

One of the great things about Spark is the ability to use on just one machine in "local mode".  Not only is this useful
for trying out spark before setting up a cluster, it makes it easy to use spark in your unit tests.  It was easy enough
to write one test using Spark, but ran into a couple of issues when we went to integrate them into test suite:

1. *Isolation*.  If one test was broken, we didn't want it to mess up the SparkContext for other tests.  Each test
should get its own clean SparkContext.
2. *Limited Logging*.  The logs from Spark are great while you're actively debugging a test.  But they are so verbose
that they get a little annoying when you want to run your whole test suite constantly.
3. *Selective Testing*.  When I'm working with code that doesn't interact with Spark at all, sometimes I want to skip
the tests involving Spark so the tests run faster.  Spark is definitely fast enough to be used in unit tests, and its way
faster than Hadoop, but they do take a little longer than our other unit tests.  And some of our unit tests with spark
crunch through millions of records, so they take a little longer.

Isolation is by far the most important, though the others are nice additions.  Isolation is also tricky, though.  We
could create a SparkContext for every test, but then we ran into these error messages:

    [info]   org.jboss.netty.channel.ChannelException: Failed to bind to: /192.168.1.100:63726
    [info]   at org.jboss.netty.bootstrap.ServerBootstrap.bind(ServerBootstrap.java:298)
    [info]   at akka.remote.netty.NettyRemoteServer.start(Server.scala:53)
    [info]   at akka.remote.netty.NettyRemoteTransport.start(NettyRemoteSupport.scala:89)
    [info]   at akka.remote.RemoteActorRefProvider.init(RemoteActorRefProvider.scala:94)
    [info]   at akka.actor.ActorSystemImpl._start(ActorSystem.scala:588)
    [info]   at akka.actor.ActorSystemImpl.start(ActorSystem.scala:595)
    [info]   at akka.actor.ActorSystem$.apply(ActorSystem.scala:111)
    [info]   at spark.util.AkkaUtils$.createActorSystem(AkkaUtils.scala:40)
    [info]   at spark.SparkEnv$.createFromSystemProperties(SparkEnv.scala:72)
    [info]   at spark.SparkContext.<init>(SparkContext.scala:99)
    [info]   ...
    [info]   Cause: java.net.BindException: Address already in use
    [info]   at sun.nio.ch.Net.bind(Native Method)

We found the solution to this problem in the unit tests in spark:

     // To avoid Akka rebinding to the same port, since it doesn't unbind immediately on shutdown
     System.clearProperty("spark.master.port")

In the unit tests for Spark itself, they use BeforeAndAfter to create a SparkContext for every test.  However, that
didn't really work for us.  Not all of the tests in one test class needed a SparkContext, and we didn't want to
make one when we didn't need it (to keep those tests fast).  We generally use [FunSuite from ScalaTest](http://www.scalatest.org/getting_started_with_fun_suite)
for our tests, so we created a new `sparkTest` method in a `SparkTestUtils` trait that we could mix into our tests:

    object SparkTest extends org.scalatest.Tag("com.qf.test.tags.SparkTest")

    trait SparkTestUtils extends FunSuite {
      var sc: SparkContext = _

      /**
       * convenience method for tests that use spark.  Creates a local spark context, and cleans
       * it up even if your test fails.  Also marks the test with the tag SparkTest, so you can
       * turn it off
       *
       * By default, it turn off spark logging, b/c it just clutters up the test output.  However,
       * when you are actively debugging one test, you may want to turn the logs on
       *
       * @param name the name of the test
       * @param silenceSpark true to turn off spark logging
       */
      def sparkTest(name: String, silenceSpark : Boolean = true)(body: => Unit) {
        def expBody = {
          val origLogLevels = if (silenceSpark) SparkUtil.silenceSpark() else null
          sc = new SparkContext("local[4]", name)
          try {
            body
          }
          finally {
            sc.stop
            sc = null
            // To avoid Akka rebinding to the same port, since it doesn't unbind immediately on shutdown
            System.clearProperty("spark.master.port")
            if (silenceSpark) Logging.setLogLevels(origLogLevels)
          }
        }
        test(name, SparkTest)(expBody)
      }
    }


We can then use this in our tests:

    class OurAwesomeClassTest extends SparkTestUtils with ShouldMatchers {
      sparkTest("spark filter") {
        val data = sc.parallelize(1 to 1e6.toInt)
        data.filter{_ % 2 == 0}.count should be (5e5.toInt)
      }

      test("non-spark code") {
        val x = 17
        val y = 3
        OurAwesomeClass.plus(x,y) should be (20)
      }
    }


Then we can run our tests within sbt:

    //running all the tests
    > test-only OurAwesomeClassTest
    12/11/02 10:45:43 INFO slf4j.Slf4jEventHandler: Slf4jEventHandler started
    12/11/02 10:45:44 INFO server.Server: jetty-7.5.3.v20111011
    12/11/02 10:45:44 INFO server.AbstractConnector: Started SelectChannelConnector@0.0.0.0:63859 STARTING
    12/11/02 10:45:44 INFO server.Server: jetty-7.5.3.v20111011
    12/11/02 10:45:44 INFO server.AbstractConnector: Started SelectChannelConnector@0.0.0.0:63860 STARTING
    [info] OurAwesomeClassTest:
    [info] - spark filter
    [info] - non-spark code
    [info] Passed: : Total 2, Failed 0, Errors 0, Passed 2, Skipped 0
    [success] Total time: 1 s, completed Nov 2, 2012 10:45:44 AM

    //skipping the spark tests, by using the tag
    > test-only OurAwesomeClassTest -- -l com.qf.test.tags.SparkTest
    [info] OurAwesomeClassTest:
    [info] - non-spark code
    [info] Passed: : Total 1, Failed 0, Errors 0, Passed 1, Skipped 0
    [success] Total time: 0 s, completed Nov 2, 2012 10:47:42 AM

    //if we wanted, we could also *only* run the spark tests, though we never really use this
    > test-only OurAwesomeClassTest -- -n com.qf.test.tags.SparkTest
    12/11/02 10:47:37 INFO slf4j.Slf4jEventHandler: Slf4jEventHandler started
    12/11/02 10:47:38 INFO server.Server: jetty-7.5.3.v20111011
    12/11/02 10:47:38 INFO server.AbstractConnector: Started SelectChannelConnector@0.0.0.0:63945 STARTING
    12/11/02 10:47:38 INFO server.Server: jetty-7.5.3.v20111011
    12/11/02 10:47:38 INFO server.AbstractConnector: Started SelectChannelConnector@0.0.0.0:63946 STARTING
    [info] OurAwesomeClassTest:
    [info] - spark filter
    [info] Passed: : Total 1, Failed 0, Errors 0, Passed 1, Skipped 0
    [success] Total time: 1 s, completed Nov 2, 2012 10:47:38 AM

You could modify the `sparkTest` method to suite your needs, eg., maybe you want to pass in the number of threads spark
should use, or if you'd prefer to have the SparkContext directly passed into the body, using the
[Loan Pattern](https://wiki.scala-lang.org/display/SYGN/Loan).  This met our needs for the moment, though, and we thought
it would be useful for others as well.
