DROP TABLE "gallery" CASCADE;
DROP TABLE "product_color" CASCADE;
DROP TABLE "product" CASCADE;
DROP TABLE "brand" CASCADE;
DROP TABLE "category" CASCADE;
DROP TABLE "country" CASCADE;
DROP TABLE "color" CASCADE;
DROP TABLE "surface" CASCADE;
DROP TABLE "users" CASCADE;
DROP TABLE "role" CASCADE;
DROP TABLE "news" CASCADE;
DROP TABLE "page" CASCADE;
DROP TABLE "page_text" CASCADE;
DROP TABLE "settings" CASCADE;

CREATE TABLE "role" (
  "id" SERIAL,
  "name" VARCHAR (255),
  PRIMARY KEY ("id")
);

INSERT INTO "role" ("name") VALUES ('admin');
INSERT INTO "role" ("name") VALUES ('user');
INSERT INTO "role" ("name") VALUES ('guest');

CREATE TABLE "users" (
  "id" BIGSERIAL,
  "username" VARCHAR(255) NOT NULL UNIQUE,
  "password" VARCHAR(63) NOT NULL,
  "email" VARCHAR(511),
  "id_role" INT REFERENCES role("id"),

  PRIMARY KEY ("id")
);

INSERT INTO "users" (username, password, email, id_role) VALUES ('admin', MD5('admin'), 'admin@example.org', (SELECT "id" FROM "role" WHERE name = 'admin'));


CREATE TABLE "page_text" (
  "id" SERIAL NOT NULL,
  "mark" VARCHAR(255) NOT NULL UNIQUE,
  "group" VARCHAR(255) NOT NULL,
  "group_title" VARCHAR(255) DEFAULT NULL,
  "position" VARCHAR(255) NOT NULL,
  "title" VARCHAR(255) NOT NULL,
  "content" TEXT,

  "created_at" TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW(),
  "updated_at" TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW(),
  PRIMARY KEY("id")
);

CREATE TABLE "page" (
  "id" BIGSERIAL NOT NULL,
  "is_published" BOOL DEFAULT 'f',

  "title" VARCHAR(255) NOT NULL,
  "content" TEXT,

  "page_url" VARCHAR(255) UNIQUE,
  "page_title" VARCHAR (255),
  "page_description" TEXT,
  "page_keywords" TEXT,

  "name" VARCHAR(255) UNIQUE,
  "is_locked" BOOL DEFAULT 'f',

  "id_parent" BIGINT REFERENCES page ("id"),
  "path" LTREE UNIQUE,

  "created_at" TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW(),
  "updated_at" TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW(),

  PRIMARY KEY("id")
);
CREATE INDEX ON page USING GIST (path);

CREATE TABLE "news" (
  "preview" TEXT,
  "published_at" TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW(),
  PRIMARY KEY("id")
) INHERITS (page);

CREATE TABLE "color" (
  "id" SERIAL NOT NULL,
  "title" VARCHAR(255) NOT NULL,
  "hex" VARCHAR(7) NOT NULL,
  PRIMARY KEY("id"),
  UNIQUE ("hex")
);

CREATE TABLE "surface" (
  "id" SERIAL NOT NULL,
  "title" VARCHAR(255) NOT NULL,
  PRIMARY KEY("id")
);

CREATE TABLE "country" (
  "id" SERIAL NOT NULL,
  "title" VARCHAR(255) NOT NULL,
  PRIMARY KEY("id")
);

CREATE TABLE "category" (
  "image" VARCHAR (255),
  PRIMARY KEY("id")
) INHERITS ("page");

CREATE TABLE "brand" (
  "image" VARCHAR (255),
  PRIMARY KEY("id")
) INHERITS ("page");

CREATE TABLE "product" (
  "article" VARCHAR(255) NOT NULL, -- артикул
  "cost" DECIMAL(10,2),            -- стоимость
  "image" VARCHAR (255),

  "id_surface" INT NOT NULL REFERENCES "surface" (id), -- тип поверхности
  "id_country" INT NOT NULL REFERENCES "country" (id), -- страна

  "is_action" BOOL DEFAULT 'f',
  "is_new" BOOL DEFAULT 'f',
  "is_hit" BOOL DEFAULT 'f',

  "width" DECIMAL(10,1),           -- размер
  "height" DECIMAL(10,1),          -- высоты
  "depth" DECIMAL(10,1),           -- толщина
  PRIMARY KEY ("id")
) INHERITS ("page");

CREATE TABLE "product_color" (
  "id" SERIAL NOT NULL,
  "title" VARCHAR(255) NOT NULL,                        -- название на русском
  "image" VARCHAR (255),                                -- изображение

  "id_color" INT NOT NULL REFERENCES "color" (id),      -- цвет
  "id_product"  INT NOT NULL REFERENCES "product" (id), -- товар
  "content" TEXT,                                   -- описание

  "is_published" BOOL DEFAULT 'f',
  "created_at" TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW(),
  "updated_at" TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW(),
  PRIMARY KEY("id")
);

CREATE TABLE "gallery" (
  "id" SERIAL NOT NULL,
  "is_published" BOOL DEFAULT 'f',
  "title" VARCHAR(255) NOT NULL,
  "image" VARCHAR (255),

  "created_at" TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW(),
  "updated_at" TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW(),
  PRIMARY KEY("id")
);

CREATE TABLE "settings" (
  "id" SERIAL NOT NULL,

  "title" VARCHAR(255) NOT NULL,
  "name" VARCHAR(255) UNIQUE,
  "value" VARCHAR(511),
  PRIMARY KEY("id")
);

CREATE OR REPLACE FUNCTION urltranslit(text) RETURNS text as $$
SELECT
regexp_replace(
	replace(
		replace(
			replace(
				replace(
					replace(
						replace(
							replace(
                translate(
                  lower($1),
                  ' абвгдеёзийклмнопрстуфхыэъь',
                  '-abvgdeezijklmnoprstufhye'
                ), 'ж',	'zh'
							), 'ц',	'ts'
						), 'ч',	'ch'
					), 'ш',	'sh'
				), 'щ',	'sch'
			), 'ю', 'yu'
		), 'я',	'ya'
	)
	,
	'[^a-z0-9-]+',
	'',
	'g'
)
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION get_calculated_page_node_path(param_page_id BIGINT) RETURNS ltree AS
$$
SELECT
  CASE WHEN p.id_parent IS NULL THEN
    p.id::text::ltree
    ELSE
      get_calculated_page_node_path(p.id_parent) || p.id::text
    END
FROM page AS p
WHERE p.id = $1;
$$
LANGUAGE sql;

CREATE OR REPLACE FUNCTION trig_update_page_node_path()
    RETURNS TRIGGER AS
    $$
    BEGIN
        IF TG_OP = 'UPDATE' THEN
            IF (COALESCE(OLD.id_parent, 0) != COALESCE(NEW.id_parent, 0) OR NEW.id != OLD.id) THEN
                -- update all nodes that are children of this one including this one
                UPDATE page
                SET path = get_calculated_page_node_path(id)
                WHERE OLD.path @> page.path;
            END IF;

        ELSIF TG_OP = 'INSERT' THEN
            UPDATE page SET path = get_calculated_page_node_path(NEW.id) WHERE page.id = NEW.id;
            IF (NEW.page_url IS NULL) THEN
                UPDATE page SET page_url = urltranslit(NEW.title) WHERE page.id = NEW.id;
            END IF;
            IF (NEW.name IS NULL) THEN
                UPDATE page SET "name" = urltranslit(NEW.title) WHERE page.id = NEW.id;
            END IF;
            IF (NEW.page_title IS NULL) THEN
                UPDATE page SET "page_title" = NEW.title WHERE page.id = NEW.id;
            END IF;

        END IF;

        RETURN NEW;
    END
    $$
LANGUAGE 'plpgsql' VOLATILE;

-- сейчас мы вешаем триггер на каждую отнаследованну таблицу от page и на саму page, см. http://www.postgresql.org/docs/9.1/static/ddl-inherit.html#DDL-INHERIT-CAVEATS
CREATE TRIGGER trig_update_page_node_path AFTER INSERT OR UPDATE OF id, id_parent
ON page FOR EACH ROW EXECUTE PROCEDURE trig_update_page_node_path();

CREATE TRIGGER trig_update_news_node_path AFTER INSERT OR UPDATE OF id, id_parent
ON news FOR EACH ROW EXECUTE PROCEDURE trig_update_page_node_path();

CREATE TRIGGER trig_update_category_node_path AFTER INSERT OR UPDATE OF id, id_parent
ON category FOR EACH ROW EXECUTE PROCEDURE trig_update_page_node_path();

CREATE TRIGGER trig_update_brand_node_path AFTER INSERT OR UPDATE OF id, id_parent
ON brand FOR EACH ROW EXECUTE PROCEDURE trig_update_page_node_path();

CREATE TRIGGER trig_update_product_node_path AFTER INSERT OR UPDATE OF id, id_parent
ON product FOR EACH ROW EXECUTE PROCEDURE trig_update_page_node_path();


-- DATA
INSERT INTO color (title, hex) VALUES ('белый', '#ffffff');
INSERT INTO color (title, hex) VALUES ('чёрный', '#000000');
INSERT INTO color (title, hex) VALUES ('красный', '#ff0000');

INSERT INTO surface (title) VALUES ('Полированный');
INSERT INTO surface (title) VALUES ('Неполированный');

INSERT INTO country (title) VALUES ('Россия');
INSERT INTO country (title) VALUES ('Италия');

INSERT INTO "page" (is_published, title, content, page_url, page_title, is_locked, name, id_parent) VALUES ('t', 'Главная', '', '', 'Главная', 't', 'main', NULL);
INSERT INTO "page" (is_published, title, content, page_url, page_title, is_locked, name, id_parent) VALUES ('t', 'Галерея', '', 'gallery', 'Галерея', 't', 'gallery', (SELECT id FROM page WHERE name = 'main'));
INSERT INTO "page" (is_published, title, content, page_url, page_title, is_locked, name, id_parent) VALUES ('t', 'Новости', '', 'news', 'Новости', 't', 'news', (SELECT id FROM page WHERE name = 'main'));

INSERT INTO category (title, is_published, id_parent) VALUES ('Керамогранит', 't', (SELECT id FROM page WHERE name = 'main'));
INSERT INTO category (title, is_published, id_parent) VALUES ('Вентфасады', 't', (SELECT id FROM page WHERE name = 'main'));

INSERT INTO brand (title, id_parent) VALUES ('Estima', (SELECT id FROM page WHERE name = 'ventfasady'));
INSERT INTO brand (title, id_parent) VALUES ('Kerama Marazzi', (SELECT id FROM page WHERE name = 'keramogranit'));
INSERT INTO brand (title, id_parent) VALUES ('Italon', (SELECT id FROM page WHERE name = 'ventfasady'));
INSERT INTO brand (title, id_parent) VALUES ('Grassaro', (SELECT id FROM page WHERE name = 'keramogranit'));

INSERT INTO product (title, article, cost, image, content, id_surface, id_country, is_action, is_new, is_hit, width, height, depth, is_published, id_parent) VALUES ('AGA6625K', 'AGA6625K', 540.00, '', 'Керамогранит Мираж - это новинка, которая интересна тем, что искусно имитирует нерукотворные трещины и канавки в камне, подвергшийся обработке. Этот керамогранит под мрамор еще раз доказывает, что природа может бесконечно давать нам повод восторгаться ее красотой.', 1, 1, true, true, true, 12.0, 12.0, 12.0, true, (SELECT id FROM page WHERE name = 'estima'));
INSERT INTO product (title, article, cost, image, content, id_surface, id_country, is_action, is_new, is_hit, width, height, depth, is_published, id_parent) VALUES ('BGA6625K', 'BGA6625K', 740.00, '', 'Керамогранит Мираж - это новинка, которая интересна тем, что искусно имитирует нерукотворные трещины и канавки в камне, подвергшийся обработке. Этот керамогранит под мрамор еще раз доказывает, что природа может бесконечно давать нам повод восторгаться ее красотой.', 1, 1, true, true, true, 20.0, 12.0, 12.0, true, (SELECT id FROM page WHERE name = 'estima'));
INSERT INTO product (title, article, cost, image, content, id_surface, id_country, is_action, is_new, is_hit, width, height, depth, is_published, id_parent) VALUES ('CGA6625K', 'CGA6625K', 340.00, '', 'Керамогранит Мираж - это новинка, которая интересна тем, что искусно имитирует нерукотворные трещины и канавки в камне, подвергшийся обработке. Этот керамогранит под мрамор еще раз доказывает, что природа может бесконечно давать нам повод восторгаться ее красотой.', 1, 1, true, true, true, 12.0, 30, 12.0, true, (SELECT id FROM page WHERE name = 'grassaro'));
INSERT INTO product (title, article, cost, image, content, id_surface, id_country, is_action, is_new, is_hit, width, height, depth, is_published, id_parent) VALUES ('DGA6625K', 'DGA6625K', 600.00, '', 'Керамогранит Мираж - это новинка, которая интересна тем, что искусно имитирует нерукотворные трещины и канавки в камне, подвергшийся обработке. Этот керамогранит под мрамор еще раз доказывает, что природа может бесконечно давать нам повод восторгаться ее красотой.', 1, 1, true, true, true, 12.0, 30, 12.0, true, (SELECT id FROM page WHERE name = 'italon'));

INSERT INTO news (title, preview, content, is_published, published_at, id_parent) VALUES ('Свежая акция!', 'Акция на полированный керамогранит в ноябре', '<p>Feeling offended by Gregor''s delayed response in opening the door, the clerk warns him of the consequences of missing work. He adds that his recent performance has been unsatisfactory. Gregor disagrees and tells him that he will open the door shortly. Nobody on the other side of the door could understand a single word he uttered (Gregor was unaware of the fact that his voice has also transformed) and conclude that he is seriously ill. Finally, Gregor manages to unlock and open the door with his mouth. He apologizes to the office manager for the delay. Horrified by the sight of Gregor''s appearance, the manager bolts out of the apartment, while Gregor''s mother faints. Gregor tries to catch up with him but his father drives him back into the bedroom with a cane and a rolled newspaper. Gregor injures himself squeezing back through the doorway, and his father slams the door shut. Gregor, exhausted, falls asleep.</p>','t', '2012-11-06', (SELECT id FROM page WHERE name = 'news'));
INSERT INTO news (title, preview, content, is_published, published_at, id_parent) VALUES ('Расширение линейки', 'Расширение линейки полированного керамогранита ', '','t', '2012-10-31', (SELECT id FROM page WHERE name = 'news'));
INSERT INTO news (title, preview, content, is_published, published_at, id_parent) VALUES ('Спешите!', 'Специальная цена до 1 ноября - белый полированный керамогранит!', '','t', '2012-10-15', (SELECT id FROM page WHERE name = 'news'));

INSERT INTO page_text (mark, "group", "group_title", "position", title, content, created_at, updated_at) VALUES ('first', 'main', 'Главная', 'Почему выбирают нас / первый блок', 'Заголовок 1', '<p>При необходимости срочного приобретения керамогранита, покупатель сталкивается с ситуацией, когда на складе продавца не всегда имеется необходимое количество материала. Отечественные производители КЕРАТОН, KERAMA MARAZZI, Italon, Grasaro заблаговременно осуществляют доставку  продукции дистрибьюторам в количестве, соответствующем спросу и объемам продаж. Поэтому компания Рекада всегда располагает достаточным количеством керамогранита Эстима и любых коллекций KERAMA MARAZZI, Italon и Grasaro. <br> В случае, когда клиент желает приобрести керамогранит оптом, он может заранее оформить заявку, чтобы мы успели</p>', '2013-04-23 04:22:44', '2013-04-23 04:22:44');
INSERT INTO page_text (mark, "group", "group_title", "position", title, content, created_at, updated_at) VALUES ('second', 'main', 'Главная', 'Почему выбирают нас / второй блок', 'Заголовок 2', '<p>При необходимости срочного приобретения керамогранита, покупатель сталкивается с ситуацией, когда на складе продавца не всегда имеется необходимое количество материала. Отечественные производители КЕРАТОН, KERAMA MARAZZI, Italon, Grasaro заблаговременно осуществляют доставку  продукции дистрибьюторам в количестве, соответствующем спросу и объемам продаж. Поэтому компания Рекада всегда располагает достаточным количеством керамогранита Эстима и любых коллекций KERAMA MARAZZI, Italon и Grasaro. <br> В случае, когда клиент желает приобрести керамогранит оптом, он может заранее оформить заявку, чтобы мы успели</p>', '2013-04-23 04:22:44', '2013-04-23 04:22:44');
INSERT INTO page_text (mark, "group", "group_title", "position", title, content, created_at, updated_at) VALUES ('third', 'main', 'Главная', 'Почему выбирают нас / третий блок', 'Заголовок 3', '<p>При необходимости срочного приобретения керамогранита, покупатель сталкивается с ситуацией, когда на складе продавца не всегда имеется необходимое количество материала. Отечественные производители КЕРАТОН, KERAMA MARAZZI, Italon, Grasaro заблаговременно осуществляют доставку  продукции дистрибьюторам в количестве, соответствующем спросу и объемам продаж. Поэтому компания Рекада всегда располагает достаточным количеством керамогранита Эстима и любых коллекций KERAMA MARAZZI, Italon и Grasaro. <br> В случае, когда клиент желает приобрести керамогранит оптом, он может заранее оформить заявку, чтобы мы успели</p>', '2013-04-23 04:22:44', '2013-04-23 04:22:44');

INSERT INTO settings (title, name, value) VALUES ('email', 'email', 'boxfrommars@gmail.com');
INSERT INTO settings (title, name, value) VALUES ('Прайс', 'price', 'price.xls');