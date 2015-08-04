# encoding: utf-8
require 'logstash/environment'

root_dir = File.expand_path(File.join(File.dirname(__FILE__), ".."))
LogStash::Environment.load_runtime_jars! File.join(root_dir, "vendor")

java_import "com.amazonaws.services.sqs.model.DeleteMessageBatchRequestEntry"
java_import "java.util.concurrent.Executors"
java_import "java.util.concurrent.atomic.AtomicInteger"
java_import "com.amazonaws.ClientConfiguration"
java_import "com.amazonaws.services.sqs.AmazonSQSAsyncClient"
java_import "com.amazonaws.services.sqs.buffered.AmazonSQSBufferedAsyncClient"
java_import "com.amazonaws.services.sqs.buffered.QueueBufferConfig"
java_import "com.amazonaws.services.sqs.model.ReceiveMessageRequest"
java_import "com.amazonaws.services.sqs.model.DeleteMessageBatchRequest"
