# Getting started with ActiveMQ Artemis

## Step 1: Install the broker

~~~ shell
curl https://raw.githubusercontent.com/ssorj/artemis-install-script/main/install.sh | sh
~~~

## Step 2: Install the AMQP command-line tools

~~~ shell
pip install --index-url https://test.pypi.org/simple/ ssorj-qtools
~~~

## Step 3: Start the broker

In a distinct terminal:

~~~ shell
artemis run
~~~

~~~
$ artemis run
     _        _               _
    / \  ____| |_  ___ __  __(_) _____
   / _ \|  _ \ __|/ _ \  \/  | |/  __/
  / ___ \ | \/ |_/  __/ |\/| | |\___ \
 /_/   \_\|   \__\____|_|  |_|_|/___ /
 Apache ActiveMQ Artemis 2.27.1

2022-12-30 09:21:34,205 INFO  [org.apache.activemq.artemis.integration.bootstrap] AMQ101000: Starting ActiveMQ Artemis Server
~~~

## Step 4: Create a queue

~~~ shell
artemis queue create --name greetings --address greetings --auto-create-address --anycast --silent
~~~

~~~
$ artemis queue create --name greetings --address greetings --auto-create-address --anycast --silent
Connection brokerURL = tcp://localhost:61616
Queue [name=greetings, address=greetings, routingType=ANYCAST, durable=false, purgeOnNoConsumers=false, autoCreateAddress=false, exclusive=false, lastValue=false, lastValueKey=null, nonDestructive=false, consumersBeforeDispatch=0, delayBeforeDispatch=-1, autoCreateAddress=false] created successfully.
~~~

## Step 5: Send a message

~~~ shell
qsend amqp://localhost/greetings hello
~~~

~~~
$ qsend amqp://localhost/greetings hello
qsend-0fb3ed4b: Created sender for target 'greetings' on server 'localhost'
qsend-0fb3ed4b: Sent 1 message
~~~

## Step 6: Receive a message

~~~ shell
qreceive amqp://localhost/greetings --count 1
~~~

~~~
$ qreceive amqp://localhost/greetings --count 1
qreceive-ab35663e: Created receiver for source 'greetings' on server 'localhost'
qreceive-ab35663e: Received 1 message
hello
~~~

## Stopping the broker

~~~ shell
artemis stop
~~~

## Logging

## TLS

## User and password

## Creating queues and topics

## Accessing the console

XXX Basic login procedure

### The default console user and password

By default, the install script creates a user named "example" with a
generated password.  The password is printed in the install script
summary.

~~~
== Summary ==

   SUCCESS

   ActiveMQ Artemis is now installed.

       Version:           2.23.1
       Config files:      /home/jross/.config/artemis
       Log files:         /home/jross/.local/state/artemis/log
       Console user:      example
       Console password:  7yjcx0l0w7k48v1a
~~~

### Changing the example user password

XXX

## Writing a client program

XXX Choose your language and write a messaging-based application
