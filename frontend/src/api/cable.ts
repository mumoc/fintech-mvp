import { createConsumer } from "@rails/actioncable";
import { getToken } from "./client";
import type { Application } from "./types";

const CABLE_URL =
  (import.meta.env.VITE_CABLE_URL as string | undefined) ?? "ws://localhost:3000/cable";

export interface ApplicationEvent {
  event: "created" | "status_changed";
  application: Application;
}

// Subscribes to realtime application updates. Returns an unsubscribe function.
export function subscribeToApplications(onMessage: (event: ApplicationEvent) => void): () => void {
  const token = getToken();
  const consumer = createConsumer(`${CABLE_URL}?token=${token ?? ""}`);
  const subscription = consumer.subscriptions.create("ApplicationsChannel", {
    received: (data: ApplicationEvent) => onMessage(data),
  });

  return () => {
    subscription.unsubscribe();
    consumer.disconnect();
  };
}
