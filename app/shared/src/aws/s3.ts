// =============================================================================
// S3 Client
// =============================================================================

import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
  DeleteObjectCommand,
  ListObjectsV2Command,
  HeadObjectCommand,
  type GetObjectCommandInput,
  type PutObjectCommandInput,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { config, getAwsEndpoint } from '../config/index.js';
import { createLogger } from '../logger.js';

const logger = createLogger('s3');

// Create S3 client
const endpoint = getAwsEndpoint();
export const s3Client = new S3Client({
  region: config.AWS_REGION,
  ...(endpoint && { endpoint }),
  forcePathStyle: config.USE_LOCALSTACK, // Required for LocalStack
  ...(config.USE_LOCALSTACK && {
    credentials: {
      accessKeyId: 'test',
      secretAccessKey: 'test',
    },
  }),
});

// Get object
export async function getObject(bucket: string, key: string): Promise<Buffer | null> {
  try {
    const input: GetObjectCommandInput = {
      Bucket: bucket,
      Key: key,
    };

    const command = new GetObjectCommand(input);
    const response = await s3Client.send(command);

    if (!response.Body) return null;

    // Convert stream to buffer
    const chunks: Uint8Array[] = [];
    for await (const chunk of response.Body as AsyncIterable<Uint8Array>) {
      chunks.push(chunk);
    }

    return Buffer.concat(chunks);
  } catch (error) {
    if ((error as { name?: string }).name === 'NoSuchKey') {
      return null;
    }
    throw error;
  }
}

// Put object
export async function putObject(
  bucket: string,
  key: string,
  body: Buffer | string,
  options?: {
    contentType?: string;
    metadata?: Record<string, string>;
    cacheControl?: string;
  },
): Promise<void> {
  const input: PutObjectCommandInput = {
    Bucket: bucket,
    Key: key,
    Body: body,
    ContentType: options?.contentType,
    Metadata: options?.metadata,
    CacheControl: options?.cacheControl,
  };

  const command = new PutObjectCommand(input);
  await s3Client.send(command);

  logger.debug({ bucket, key }, 'S3 object uploaded');
}

// Delete object
export async function deleteObject(bucket: string, key: string): Promise<void> {
  const command = new DeleteObjectCommand({
    Bucket: bucket,
    Key: key,
  });

  await s3Client.send(command);
  logger.debug({ bucket, key }, 'S3 object deleted');
}

// Check if object exists
export async function objectExists(bucket: string, key: string): Promise<boolean> {
  try {
    const command = new HeadObjectCommand({
      Bucket: bucket,
      Key: key,
    });

    await s3Client.send(command);
    return true;
  } catch (error) {
    if ((error as { name?: string }).name === 'NotFound') {
      return false;
    }
    throw error;
  }
}

// List objects
export async function listObjects(
  bucket: string,
  prefix?: string,
  options?: {
    maxKeys?: number;
    continuationToken?: string;
  },
): Promise<{ keys: string[]; nextToken?: string }> {
  const command = new ListObjectsV2Command({
    Bucket: bucket,
    Prefix: prefix,
    MaxKeys: options?.maxKeys,
    ContinuationToken: options?.continuationToken,
  });

  const response = await s3Client.send(command);

  const result: { keys: string[]; nextToken?: string } = {
    keys: response.Contents?.map((obj) => obj.Key!).filter(Boolean) ?? [],
  };
  if (response.NextContinuationToken) {
    result.nextToken = response.NextContinuationToken;
  }
  return result;
}

// Generate presigned URL for upload
export async function getUploadUrl(
  bucket: string,
  key: string,
  options?: {
    expiresIn?: number;
    contentType?: string;
  },
): Promise<string> {
  const command = new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    ContentType: options?.contentType,
  });

  return getSignedUrl(s3Client, command, {
    expiresIn: options?.expiresIn ?? 3600,
  });
}

// Generate presigned URL for download
export async function getDownloadUrl(
  bucket: string,
  key: string,
  options?: {
    expiresIn?: number;
  },
): Promise<string> {
  const command = new GetObjectCommand({
    Bucket: bucket,
    Key: key,
  });

  return getSignedUrl(s3Client, command, {
    expiresIn: options?.expiresIn ?? 3600,
  });
}
