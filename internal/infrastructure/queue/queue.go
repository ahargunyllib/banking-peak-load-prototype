package queue

import amqp "github.com/rabbitmq/amqp091-go"

type Client struct {
	Conn    *amqp.Connection
	Channel *amqp.Channel
}

func New(url string) (*Client, error) {
	conn, err := amqp.Dial(url)
	if err != nil {
		return nil, err
	}
	ch, err := conn.Channel()
	if err != nil {
		conn.Close()
		return nil, err
	}
	if _, err = ch.QueueDeclare("transactions.dlq", true, false, false, false, nil); err != nil {
		ch.Close()
		conn.Close()
		return nil, err
	}
	args := amqp.Table{
		"x-dead-letter-exchange":    "",
		"x-dead-letter-routing-key": "transactions.dlq",
	}
	if _, err = ch.QueueDeclare("transactions", true, false, false, false, args); err != nil {
		ch.Close()
		conn.Close()
		return nil, err
	}
	return &Client{Conn: conn, Channel: ch}, nil
}

func (c *Client) Close() {
	c.Channel.Close()
	c.Conn.Close()
}
