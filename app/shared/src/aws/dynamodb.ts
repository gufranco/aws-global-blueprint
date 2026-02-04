// =============================================================================
// DynamoDB Client
// =============================================================================

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  UpdateCommand,
  DeleteCommand,
  QueryCommand,
  ScanCommand,
  type GetCommandInput,
  type PutCommandInput,
  type UpdateCommandInput,
  type DeleteCommandInput,
  type QueryCommandInput,
  type ScanCommandInput,
} from '@aws-sdk/lib-dynamodb';
import { config, getAwsEndpoint } from '../config/index.js';
import { createLogger } from '../logger.js';

const logger = createLogger('dynamodb');

// Create DynamoDB client
const endpoint = getAwsEndpoint();
const dynamoClient = new DynamoDBClient({
  region: config.AWS_REGION,
  ...(endpoint && { endpoint }),
  ...(config.USE_LOCALSTACK && {
    credentials: {
      accessKeyId: 'test',
      secretAccessKey: 'test',
    },
  }),
});

// Document client with marshalling
export const dynamoDb = DynamoDBDocumentClient.from(dynamoClient, {
  marshallOptions: {
    convertEmptyValues: true,
    removeUndefinedValues: true,
  },
  unmarshallOptions: {
    wrapNumbers: false,
  },
});

// Get item by key
export async function getItem<T>(
  tableName: string,
  key: Record<string, unknown>
): Promise<T | null> {
  const input: GetCommandInput = {
    TableName: tableName,
    Key: key,
  };

  const command = new GetCommand(input);
  const response = await dynamoDb.send(command);

  return (response.Item as T) ?? null;
}

// Put item
export async function putItem<T extends Record<string, unknown>>(
  tableName: string,
  item: T,
  options?: {
    conditionExpression?: string;
    expressionAttributeNames?: Record<string, string>;
    expressionAttributeValues?: Record<string, unknown>;
  }
): Promise<void> {
  const input: PutCommandInput = {
    TableName: tableName,
    Item: item,
    ConditionExpression: options?.conditionExpression,
    ExpressionAttributeNames: options?.expressionAttributeNames,
    ExpressionAttributeValues: options?.expressionAttributeValues,
  };

  const command = new PutCommand(input);
  await dynamoDb.send(command);

  logger.debug({ tableName, item }, 'DynamoDB item put');
}

// Update item
export async function updateItem<T>(
  tableName: string,
  key: Record<string, unknown>,
  updates: Record<string, unknown>,
  options?: {
    conditionExpression?: string;
    returnValues?: 'NONE' | 'ALL_OLD' | 'UPDATED_OLD' | 'ALL_NEW' | 'UPDATED_NEW';
  }
): Promise<T | null> {
  // Build update expression
  const updateExpressionParts: string[] = [];
  const expressionAttributeNames: Record<string, string> = {};
  const expressionAttributeValues: Record<string, unknown> = {};

  let index = 0;
  for (const [field, value] of Object.entries(updates)) {
    const nameKey = `#f${index}`;
    const valueKey = `:v${index}`;
    updateExpressionParts.push(`${nameKey} = ${valueKey}`);
    expressionAttributeNames[nameKey] = field;
    expressionAttributeValues[valueKey] = value;
    index++;
  }

  const input: UpdateCommandInput = {
    TableName: tableName,
    Key: key,
    UpdateExpression: `SET ${updateExpressionParts.join(', ')}`,
    ExpressionAttributeNames: expressionAttributeNames,
    ExpressionAttributeValues: expressionAttributeValues,
    ConditionExpression: options?.conditionExpression,
    ReturnValues: options?.returnValues ?? 'ALL_NEW',
  };

  const command = new UpdateCommand(input);
  const response = await dynamoDb.send(command);

  return (response.Attributes as T) ?? null;
}

// Delete item
export async function deleteItem(
  tableName: string,
  key: Record<string, unknown>,
  options?: {
    conditionExpression?: string;
  }
): Promise<void> {
  const input: DeleteCommandInput = {
    TableName: tableName,
    Key: key,
    ConditionExpression: options?.conditionExpression,
  };

  const command = new DeleteCommand(input);
  await dynamoDb.send(command);

  logger.debug({ tableName, key }, 'DynamoDB item deleted');
}

// Query items
export async function queryItems<T>(
  tableName: string,
  keyConditionExpression: string,
  expressionAttributeValues: Record<string, unknown>,
  options?: {
    indexName?: string;
    filterExpression?: string;
    expressionAttributeNames?: Record<string, string>;
    limit?: number;
    scanIndexForward?: boolean;
    exclusiveStartKey?: Record<string, unknown>;
  }
): Promise<{ items: T[]; lastKey?: Record<string, unknown> }> {
  const input: QueryCommandInput = {
    TableName: tableName,
    KeyConditionExpression: keyConditionExpression,
    ExpressionAttributeValues: expressionAttributeValues,
    IndexName: options?.indexName,
    FilterExpression: options?.filterExpression,
    ExpressionAttributeNames: options?.expressionAttributeNames,
    Limit: options?.limit,
    ScanIndexForward: options?.scanIndexForward,
    ExclusiveStartKey: options?.exclusiveStartKey,
  };

  const command = new QueryCommand(input);
  const response = await dynamoDb.send(command);

  const result: { items: T[]; lastKey?: Record<string, unknown> } = {
    items: (response.Items as T[]) ?? [],
  };
  if (response.LastEvaluatedKey) {
    result.lastKey = response.LastEvaluatedKey;
  }
  return result;
}

// Scan items (use sparingly)
export async function scanItems<T>(
  tableName: string,
  options?: {
    filterExpression?: string;
    expressionAttributeNames?: Record<string, string>;
    expressionAttributeValues?: Record<string, unknown>;
    limit?: number;
    exclusiveStartKey?: Record<string, unknown>;
  }
): Promise<{ items: T[]; lastKey?: Record<string, unknown> }> {
  const input: ScanCommandInput = {
    TableName: tableName,
    FilterExpression: options?.filterExpression,
    ExpressionAttributeNames: options?.expressionAttributeNames,
    ExpressionAttributeValues: options?.expressionAttributeValues,
    Limit: options?.limit,
    ExclusiveStartKey: options?.exclusiveStartKey,
  };

  const command = new ScanCommand(input);
  const response = await dynamoDb.send(command);

  const result: { items: T[]; lastKey?: Record<string, unknown> } = {
    items: (response.Items as T[]) ?? [],
  };
  if (response.LastEvaluatedKey) {
    result.lastKey = response.LastEvaluatedKey;
  }
  return result;
}
