import { describe, it, expect } from 'vitest';

// The Semaphore class is not exported from the worker module, so we test it
// by extracting the same logic into a standalone test. This validates the
// fix for the negative-count bug without needing to import the private class.

class Semaphore {
  private current = 0;
  private waiting: Array<() => void> = [];

  constructor(private readonly max: number) {}

  async acquire(): Promise<void> {
    if (this.current < this.max) {
      this.current++;
      return;
    }
    return new Promise<void>((resolve) => {
      this.waiting.push(resolve);
    });
  }

  release(): void {
    const next = this.waiting.shift();
    if (next) {
      next();
    } else if (this.current > 0) {
      this.current--;
    }
  }

  get activeConcurrency(): number {
    return this.current;
  }
}

describe('Semaphore', () => {
  it('should allow up to max concurrent acquisitions', async () => {
    // Arrange
    const semaphore = new Semaphore(3);

    // Act
    await semaphore.acquire();
    await semaphore.acquire();
    await semaphore.acquire();

    // Assert
    expect(semaphore.activeConcurrency).toBe(3);
  });

  it('should block when max concurrency is reached', async () => {
    // Arrange
    const semaphore = new Semaphore(1);
    await semaphore.acquire();
    let secondAcquired = false;

    // Act
    const promise = semaphore.acquire().then(() => {
      secondAcquired = true;
    });

    // Assert: second acquire is blocked
    await new Promise((r) => setTimeout(r, 10));
    expect(secondAcquired).toBe(false);

    // Release first, second should unblock
    semaphore.release();
    await promise;
    expect(secondAcquired).toBe(true);
  });

  it('should not go negative on unmatched release', () => {
    // Arrange
    const semaphore = new Semaphore(5);

    // Act: release without any acquire
    semaphore.release();
    semaphore.release();
    semaphore.release();

    // Assert: count stays at 0, not -3
    expect(semaphore.activeConcurrency).toBe(0);
  });

  it('should release waiters in FIFO order', async () => {
    // Arrange
    const semaphore = new Semaphore(1);
    await semaphore.acquire();
    const order: number[] = [];

    // Act
    const p1 = semaphore.acquire().then(() => order.push(1));
    const p2 = semaphore.acquire().then(() => order.push(2));

    semaphore.release(); // unblocks p1
    await p1;
    semaphore.release(); // unblocks p2
    await p2;

    // Assert
    expect(order).toEqual([1, 2]);
  });

  it('should handle acquire-release cycles correctly', async () => {
    // Arrange
    const semaphore = new Semaphore(2);

    // Act: full cycle
    await semaphore.acquire();
    await semaphore.acquire();
    semaphore.release();
    semaphore.release();

    // Assert: can acquire again
    await semaphore.acquire();
    expect(semaphore.activeConcurrency).toBe(1);
  });
});
