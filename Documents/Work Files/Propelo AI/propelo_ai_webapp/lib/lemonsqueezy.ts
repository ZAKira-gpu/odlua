// Lemon Squeezy API Client

const LEMONSQUEEZY_API_URL = "https://api.lemonsqueezy.com/v1";

interface LemonSqueezyConfig {
  apiKey: string;
  storeId: string;
}

class LemonSqueezyClient {
  private apiKey: string;
  private storeId: string;

  constructor(config: LemonSqueezyConfig) {
    this.apiKey = config.apiKey;
    this.storeId = config.storeId;
  }

  private async request(endpoint: string, options: RequestInit = {}) {
    const url = `${LEMONSQUEEZY_API_URL}${endpoint}`;
    const response = await fetch(url, {
      ...options,
      headers: {
        "Accept": "application/vnd.api+json",
        "Content-Type": "application/vnd.api+json",
        "Authorization": `Bearer ${this.apiKey}`,
        ...options.headers,
      },
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(
        `Lemon Squeezy API error: ${response.status} - ${JSON.stringify(error)}`
      );
    }

    return response.json();
  }

  // Get subscription details
  async getSubscription(subscriptionId: string) {
    return this.request(`/subscriptions/${subscriptionId}`);
  }

  // Get customer details
  async getCustomer(customerId: string) {
    return this.request(`/customers/${customerId}`);
  }

  // Create checkout session
  async createCheckout(data: {
    variantId: string;
    customerId?: string;
    email?: string;
    customData?: Record<string, any>;
    redirectUrl?: string;
  }) {
    const checkoutData: any = {
      email: data.email || "",
      custom: data.customData || {},
    };

    const attributes: any = {
      checkout_data: checkoutData,
    };

    // Add product options with redirect URL if provided
    if (data.redirectUrl) {
      attributes.product_options = {
        redirect_url: data.redirectUrl,
      };
    }

    return this.request("/checkouts", {
      method: "POST",
      body: JSON.stringify({
        data: {
          type: "checkouts",
          attributes,
          relationships: {
            store: {
              data: {
                type: "stores",
                id: this.storeId,
              },
            },
            variant: {
              data: {
                type: "variants",
                id: data.variantId,
              },
            },
          },
        },
      }),
    });
  }

  // Cancel subscription
  async cancelSubscription(subscriptionId: string) {
    return this.request(`/subscriptions/${subscriptionId}`, {
      method: "PATCH",
      body: JSON.stringify({
        data: {
          type: "subscriptions",
          id: subscriptionId,
          attributes: {
            cancelled: true,
          },
        },
      }),
    });
  }

  // Resume subscription
  async resumeSubscription(subscriptionId: string) {
    return this.request(`/subscriptions/${subscriptionId}`, {
      method: "PATCH",
      body: JSON.stringify({
        data: {
          type: "subscriptions",
          id: subscriptionId,
          attributes: {
            cancelled: false,
          },
        },
      }),
    });
  }

  // Update subscription
  async updateSubscription(subscriptionId: string, data: { variantId?: string; pause?: boolean }) {
    const attributes: any = {};
    
    if (data.variantId) {
      attributes.variant_id = data.variantId;
    }
    
    if (data.pause !== undefined) {
      attributes.pause = data.pause ? { mode: "void" } : null;
    }

    return this.request(`/subscriptions/${subscriptionId}`, {
      method: "PATCH",
      body: JSON.stringify({
        data: {
          type: "subscriptions",
          id: subscriptionId,
          attributes,
        },
      }),
    });
  }

  // Verify webhook signature
  verifyWebhookSignature(payload: string, signature: string, secret: string): boolean {
    const crypto = require("crypto");
    const hmac = crypto.createHmac("sha256", secret);
    const digest = hmac.update(payload).digest("hex");
    return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(digest));
  }
}

// Initialize client
export const lemonSqueezy = new LemonSqueezyClient({
  apiKey: process.env.LEMONSQUEEZY_API_KEY || "",
  storeId: process.env.LEMONSQUEEZY_STORE_ID || "",
});

export default lemonSqueezy;
