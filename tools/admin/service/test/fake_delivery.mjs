import { parseOperatorMessage } from '../../../../functions/lib/inbox/operator.js';

/** In-memory boundary for UI verification; never initializes Firebase or contacts a project. */
export function fakeDelivery() {
  const delivered = new Map();
  const attempts = new Set();
  return { delivered, deliver: async (projectId, message) => {
    const { messageId } = parseOperatorMessage(message);
    const key = `${projectId}:${messageId}`;
    if (message.uid === 'missing-player') throw Object.assign(new Error('Player account not found.'), { code: 'not-found' });
    if (delivered.has(key) && JSON.stringify(delivered.get(key)) !== JSON.stringify(message)) {
      throw Object.assign(new Error('Delivery identity was reused with different content.'), { code: 'already-exists' });
    }
    delivered.set(key, message);
    if (message.uid === 'retry-player' && !attempts.has(key)) {
      attempts.add(key);
      throw new Error('Simulated lost response after commit');
    }
    return messageId;
  } };
}
