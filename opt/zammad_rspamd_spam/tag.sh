#!/bin/bash

# --- CONFIGURATION ---
ZAMMAD_URL="https://zammad-url"
ZAMMAD_TOKEN="zammad_token"
RSPAMD_PASSWORD="rspamd_password"
QUERY_SPAM='tags:spam'   # Adjust to your Zammad spam query
QUERY_HAM='tags:ham'     # Adjust to your Zammad ham query
RSPAMD_IN_DOCKER="true"

AUTH_HEADER="Authorization: Token token=$ZAMMAD_TOKEN"

# --- FUNCTIONS ---

process_zammad() {
  local process_spam=$1
  local query
  if [ "$process_spam" = "true" ]; then
    query="$QUERY_SPAM"
  else
    query="$QUERY_HAM"
  fi

  echo "Searching tickets with query: $query"
  local tickets
  tickets=$(curl -s -H "$AUTH_HEADER" "$ZAMMAD_URL/api/v1/search?query=$query" | jq '.result[] | select(.type=="Ticket") | .id')

  if [ -z "$tickets" ]; then
    echo "No tickets found for query: $query"
    return
  fi

  for ticket_id in $tickets; do
    echo "Processing ticket $ticket_id"
    articles=$(curl -s -H "$AUTH_HEADER" "$ZAMMAD_URL/api/v1/ticket_articles/by_ticket/$ticket_id" | jq '.[0].id')
    echo ${articles[@]}
    for article_id in $articles; do
      echo "  Fetching article $article_id"
      #plain_article=$(curl -s -H "$AUTH_HEADER" "$ZAMMAD_URL/api/v1/ticket_article_plain/$article_id")
      curl -s -H "Authorization: Token token=$ZAMMAD_TOKEN" "$ZAMMAD_URL/api/v1/ticket_article_plain/$article_id" -o tempmail
      echo "  Sending to rspamd: $article_id (first 100 chars):"
      echo "$plain_article" | head -c 100
      echo
      # Save a temp file
      # Learn as spam or ham
      if [ "$process_spam" = "true" ]; then
        if [ "$RSPAMD_IN_DOCKER" == "true" ]; then
                cat tempmail | docker exec -i mailcowdockerized_rspamd-mailcow_1 rspamc -P "$RSPAMD_PASSWORD" learn_spam
        else
                cat tempmail | rspamc -P "$RSPAMD_PASSWORD" learn_spam
        fi
      else
        if [ "$RSPAMD_IN_DOCKER" == "true" ]; then
                cat tempmail | docker exec -i mailcowdockerized_rspamd-mailcow_1 rspamc -P "$RSPAMD_PASSWORD" learn_ham
        else
                cat tempmail | rspamc -P "$RSPAMD_PASSWORD" learn_ham
        fi
      fi

      # Mark ticket as learned
      curl -s -X PUT -H "$AUTH_HEADER" -H 'Content-Type: application/json' \
        -d '{"lernd":"true"}' \
        "$ZAMMAD_URL/api/v1/tickets/$ticket_id" >/dev/null
      echo "  Marked ticket $ticket_id as learned"
    done
    echo "--------"
  done
}

# --- MAIN EXECUTION ---

process_zammad true   # Process spam
process_zammad false  # Process ham

echo "Done."
