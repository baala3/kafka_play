## Kafka Play (Simple Session Management with Karafka)

A simple Kafka & Ruby project using the [Karafka gem](https://github.com/karafka/karafka).

This project is for learning purposes only, following real-world implementation.

### Problem:

Many applications, especially those requiring authentication (like web apps), need to manage user sessions. This includes handling session expiration due to inactivity or explicit logout. Automatically logging users out after a period of inactivity is crucial for both security and user experience.

### Simple solution with kafka:

**Producer:**

A service emits user session activity events to a Kafka topic (e.g., user-sessions).
Example event details:

```
{ "user_id": 123,
 "session_id": "abc123",
 "activity_timestamp": "2025-02-07T12:00:00Z"
}
```

Events are produced whenever user activity occurs (e.g., clicking a button, viewing a page).

In this case, a simple Rack task to emits such logs.

**Consumer 1 (SessionActivityTracker):**

- Listens to the user-sessions topic and tracks user activity.
- Monitors inactivity by checking the time since the last recorded activity.
- If a session remains idle for a predefined period (e.g., 1 hour), it marks the session as expired and logs the event.

**Consumer 2: (SessionExpiryHandler):**

- Listens for expired session events from Consumer 1.
- Once an expired session is received, it can performs actions (Logging the user out, sending notification or revoke user tokens etc.)

## Setup

1. Run Kafka using docker

```shell
docker run -d -p 9092:9092 \
  --name broker \
  -e KAFKA_NODE_ID=1 \
  -e KAFKA_PROCESS_ROLES=broker,controller \
  -e KAFKA_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://127.0.0.1:9092 \
  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT \
  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@localhost:9093 \
  -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
  -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 \
  -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 \
  -e KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=0 \
  -e KAFKA_NUM_PARTITIONS=3 \
  apache/kafka:latest
```

check the connection
`nc -zv 127.0.0.1 9092` -> Connection to 127.0.0.1 port 9092 succeeded!

2. Clone and install the project

```shell
git clone git@github.com:Catsuko/karafka_playground.git
cd karafka_play
bundle
```

3. Create Kafka topics

```shell
bundle exec karafka topics reset
```

## Run the App

First produce session logs with the following rake task:

```shell
bundle exec rake producer:produce_session_logs
```

- Our app filter active logs by consuming the `session_logs` topic with `SessionActivityTracker`, which fetches expired sessions and sends them to `expired_sessions` topic at set intervals.
- `SessionExpiryHandler` which is subscribed to `expired_sessions` topic then processes these sessions logs.

Run the consumers with the karafka gem and then watch the output to see this in action:

```shell
bundle exec karafka server
```

## Kafka Web-UI

[Karafka Web UI](https://karafka.io/docs/Web-UI-About/) is a user interface for the Karafka framework.

You can run the Web UI locally with the following command:

`rackup karafka_web.ru`

Once it's running, access the real-time metrics dashboard at:
http://localhost:9292/dashboard

## others

You can also start and stop multiple servers to see the fault tolerance and horizontal scaling work.

ref:

- https://www.youtube.com/watch?v=-NMDqqW1uCE
