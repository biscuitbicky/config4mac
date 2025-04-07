%option noyywrap
%option yylineno
%option outfile="scanner.c"

%{

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>

#define TABLE_SIZE 21

enum Error {
	END = 0,
	IIL = 1, 
	ITL = 2,
	CHU = 3,
	CHE = 4,
	CHN = 5,
	CMU = 6
};

typedef struct key_value_pair {
    char* key;
    int value;
    struct key_value_pair* next;
} kv_pair;

typedef struct {
    kv_pair* table[TABLE_SIZE];
} hash_table;

typedef struct token_node {
	int   line;
	char* type;
	char* info;
	struct token_node* next;
} tnode;

int num_chars = 0;
int idx_chars = 0;
hash_table* rw_table = NULL;
tnode* token_head = NULL;

int hash(char* key);
hash_table* create_hash_table();
void hash_table_insert(hash_table* ht, char* key, int value);
void rw_table_build();
int hash_table_find(hash_table* ht, char* key);
void destroy_hash_table(hash_table* ht);

char* integer_format();
char* string_toupper();
char* allocate_token_node_info();
tnode* token_list_create_node(char* type, char* info);
void token_list_push_back_intc(tnode** pphead, char* type);
void token_list_push_back_reserved_word(tnode** pphead, char* type);
void token_list_push_back_eof(tnode** pphead, char* type);
void token_list_push_back(tnode** pphead, char* type);
void token_list_destroy(tnode** pphead);

/*void token_list_push_back_operator(char* operator) {
	if (!strcmp(operator, "."))  token_list_push_back(&token_head, "Other", "DOT");
	if (!strcmp(operator, ":=")) token_list_push_back(&token_head, "Other", "ASSIGN");
	if (!strcmp(operator, "="))  token_list_push_back(&token_head, "Other", "EQ");
	if (!strcmp(operator, "<"))  token_list_push_back(&token_head, "Other", "LT");
	if (!strcmp(operator, "+"))  token_list_push_back(&token_head, "Other", "PLUS");
	if (!strcmp(operator, "-"))  token_list_push_back(&token_head, "Other", "MINUS");
	if (!strcmp(operator, "*"))  token_list_push_back(&token_head, "Other", "TIMES");
	if (!strcmp(operator, "/"))  token_list_push_back(&token_head, "Other", "OVER");
	if (!strcmp(operator, ","))  token_list_push_back(&token_head, "Other", "COMMA");
	if (!strcmp(operator, "["))  token_list_push_back(&token_head, "Other", "LMIDPAREN");
	if (!strcmp(operator, "]"))  token_list_push_back(&token_head, "Other", "RMIDPAREN");
	if (!strcmp(operator, "..")) token_list_push_back(&token_head, "Other", "UNDERRANGE");
	if (!strcmp(operator, ";"))  token_list_push_back(&token_head, "Other", "SEMI");
	if (!strcmp(operator, "("))  token_list_push_back(&token_head, "Other", "LMIDPAREN");
	if (!strcmp(operator, ")"))  token_list_push_back(&token_head, "Other", "RMIDPAREN");
}*/

%}


INT                   [0-9]+
ID                    [a-zA-Z][a-zA-Z0-9]*
DELIMITERS            [\.=<\+\-\*/:,\[\];()]|:=|\.\.
RESERVED_WORD         program|procedure|type|var|if|then|else|fi|while|do|endwh|begin|end|read|write|array|of|record|return|integer|char


%%

[\n]                  { num_chars+=idx_chars; idx_chars=0; }
{INT}                 { token_list_push_back_intc(&token_head,"INTC"); idx_chars+=yyleng; }
{ID}                  { if (hash_table_find(rw_table, yytext) != -1) token_list_push_back_reserved_word(&token_head,"Reserved_word"); else token_list_push_back(&token_head,"ID"); idx_chars+=yyleng; }
{DELIMITERS}          { token_list_push_back(&token_head,"Other"); idx_chars+=yyleng; }
[ \t\r]               { }
<<EOF>>               { token_list_push_back_eof(&token_head,"EOF"); return 0; }

'[^'\n]*'             { if(yyleng == 2) { token_list_push_back(&token_head,"ERROR"); return CHE; } if (yyleng > 3) { token_list_push_back(&token_head,"ERROR"); return CHN; } token_list_push_back(&token_head,"CHARC"); idx_chars+=yyleng; }
'[^'\n]*\n            { token_list_push_back(&token_head,"ERROR"); return CHU; }
\{[^}]*\}             { }
\{[^}\<\<EOF\>\>]*    { }

{INT}{ID}             { token_list_push_back(&token_head,"ERROR"); return IIL; }
[^0-9a-zA-Z\n \t\r{DELIMITERS}] { token_list_push_back(&token_head,"ERROR"); return IIL; }

%%


int hash(char* key) {
    int hash = 0;
    for (int i = 0; key[i] != '\0'; i++) {
        hash = (hash + key[i]) % TABLE_SIZE;
    }
    return hash;
}

hash_table* create_hash_table() {
    hash_table* ht = (hash_table*)malloc(sizeof(hash_table));
    for (int i = 0; i < TABLE_SIZE; i++) {
        ht->table[i] = NULL;
    }
    return ht;
}

void hash_table_insert(hash_table* ht, char* key, int value) {
    int index = hash(key);
    kv_pair* kvp = (kv_pair*)malloc(sizeof(kv_pair));
    kvp->key = strdup(key);
    kvp->value = value;
    kvp->next = NULL;

    if (ht->table[index] == NULL) {
        ht->table[index] = kvp;
    } else { 
        kv_pair* curr = ht->table[index];
        while (curr->next != NULL) {
            curr = curr->next;
        }
        curr->next = kvp;
    }
}

void rw_table_build() {
	rw_table = create_hash_table();
	char* reserved_word[21] = {"program","procedure","type","var","if","then","else","fi","while","do","endwh","begin","end","read","write","array","of","record","return","integer","char"};
	int value = 0;
	for (int i = 0; i < 21; ++i) 
		hash_table_insert(rw_table, reserved_word[i], ++value);
}

int hash_table_find(hash_table* ht, char* key) {
    int index = hash(key);
    kv_pair* curr = ht->table[index];
    while (curr != NULL) {
        if (strcmp(curr->key, key) == 0) {
            return curr->value;
        }
        curr = curr->next;
    }
    return -1;
}

void destroy_hash_table(hash_table* ht) {
    for (int i = 0; i < TABLE_SIZE; i++) {
        kv_pair* curr = ht->table[i];
        while (curr != NULL) {
            kv_pair* temp = curr;
            curr = curr->next;
            free(temp->key);
            free(temp);
        }
    }
    free(ht);
}

char* integer_format() {
	int i = 0, j = 0;
	char* format = (char*)calloc(yyleng, sizeof(char));

	while (yytext[i] == '0') ++i;

	if (i == yyleng) {
		format[0] = '0';
		return format;
	}

	while (yytext[i]) format[j++] = yytext[i++];
	return format;
}

char* string_toupper() {
	char* type = (char*)malloc(sizeof(yytext));
	for (int i = 0; i < yyleng; ++i) type[i] = yytext[i] - 32;
	return type;
}

char* allocate_token_node_info() {
	char* type = (char*)malloc(sizeof(yytext));
	memcpy(type, yytext, yyleng);
	return type;
}

tnode* token_list_create_node(char* type, char* info) {
	tnode* newnode = (tnode*)malloc(sizeof(tnode));
	newnode->line = yyget_lineno();
	newnode->type = type;
	newnode->info = info;
	return newnode;
}

void token_list_push_back_intc(tnode** pphead, char* type) {
	assert(pphead);	
	tnode* newnode = token_list_create_node(type, integer_format());
	if (*pphead == NULL) *pphead = newnode;
	else {
		tnode* tail = *pphead;
		while (tail->next) tail = tail->next;
		tail->next = newnode;
	}
}

void token_list_push_back_reserved_word(tnode** pphead, char* type) {
	assert(pphead);	
	tnode* newnode = token_list_create_node(type, string_toupper());
	if (*pphead == NULL) *pphead = newnode;
	else {
		tnode* tail = *pphead;
		while (tail->next) tail = tail->next;
		tail->next = newnode;
	}
}

void token_list_push_back_eof(tnode** pphead, char* type) {
	assert(pphead);	
	tnode* newnode = token_list_create_node(type, strdup("EOF"));
	if (*pphead == NULL) *pphead = newnode;
	else {
		tnode* tail = *pphead;
		while (tail->next) tail = tail->next;
		tail->next = newnode;
	}
}

void token_list_push_back(tnode** pphead, char* type) {
	assert(pphead);	
	tnode* newnode = token_list_create_node(type, allocate_token_node_info());
	if (*pphead == NULL) *pphead = newnode;
	else {
		tnode* tail = *pphead;
		while (tail->next) tail = tail->next;
		tail->next = newnode;
	}
}

void token_list_destroy(tnode** pphead) {
	assert(pphead);
	tnode* current = *pphead;
	while (current) {
		tnode* next = current->next;
		free(current->info);
		free(current);
		current = next;
	}
	*pphead = NULL;
}

void print_token(tnode* token_head) {
	tnode* current = token_head;
	while (current) {
		printf("%d %s %s\n", 
			current->line, current->type, current->info);
		current = current->next;
	}
}

void print_token_table(tnode* token_head) {
	printf("          TOKEN TABLE\n");
	printf("+------+---------------+--------------+\n");
	printf("| Line |     Type      |     Info     |\n");

	tnode* current = token_head;
	while (current) {
		printf("|  %02d  | %-14s| %-13s|\n",
			current->line, current->type, current->info);
		current = current->next;
	}

	printf("+------+---------------+--------------+\n");
	printf("Lines: %d\n", yyget_lineno());
	printf("Chars: %d\n", num_chars);
}

void print_error(int error) {
	printf("Line %d, %d: %s: ", yyget_lineno(), idx_chars, yytext);
	switch (error) {
		case IIL: printf("illegal identifier. \n"); break;
		case ITL: printf("identifier too long. \n"); break;
		case CHU: printf("unclosed charc. \n"); break;
		case CHN: printf("not a charc. \n"); break;
		case CHE: printf("empty charc. \n"); break;
	}
	/* printf("%s\n", error_description); */
}

int main(int argc, char* argv[]) {
	rw_table_build();

	yyset_lineno(0);
	int yyret = yylex();
	int ret = yyret;
	while (yyret) {
		print_error(yyret);
		yyret = yylex();
	}

	if (!strcmp(argv[argc-1], "--print")) 
		print_token_table(token_head);
	else if (!ret)  
		print_token(token_head);

	token_list_destroy(&token_head);
	destroy_hash_table(rw_table);
	rw_table = NULL;
	return ret;
}
