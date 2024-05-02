

/* ALL WORKERS */

CREATE OR REPLACE VIEW ALL_WORKERS AS                                               /* Création de la vue */
SELECT                                                                              /* Selection des informations voulue (nom de famille, prénom age) */
    last_name,     
    first_name,
    age,
    first_day AS start_date                                                         /* Harmonise les nomination de colonne (worker1 = first_day et worker2 = start_date), un alias pour harmoniser */
FROM 
    WORKERS_FACTORY_1

WHERE                                                                               /* condition pour extraire seulement les employé encore dans l'entreprise */
    last_day IS NULL     

UNION ALL

SELECT 
    last_name,
    first_name,
    NULL AS age,                                                                    /* worker2 n'a pas de colonnne age */
    start_date
FROM 
    WORKERS_FACTORY_2
WHERE
    end_date IS NULL                                                                /* condition pour extraire seulement les employé encore dans l'entreprise */

ORDER BY
    start_date DESC;




/* ALL WORKERS ELAPSED */ 

CREATE OR REPLACE VIEW ALL_WORKERS_ELAPSED AS
SELECT 
    last_name,
    first_name,
    age,
    start_date,
    TRUNC(SYSDATE - start_date) AS days_elapsed                                     /* Permet d'avoir un entier en sortie */
FROM 
    ALL_WORKERS;




/* BEST SUPPLIER */ 

CREATE OR REPLACE VIEW BEST_SUPPLIERS AS
SELECT 
    s.name AS supplier_name,
    SUM(sb.quantity) AS total_quantity                                              /* somme des quantité par fournisseur */
FROM 
    SUPPLIERS s
INNER JOIN                                                                          /* jointure entre SUPPLIER BRING TO FACTO et SUPPLIER avec supplier.ide */
    SUPPLIERS_BRING_TO_FACTORY_1 sb ON s.supplier_id = sb.supplier_id
GROUP BY 
    s.name
HAVING 
    SUM(sb.quantity) > 1000                                                         /* groupe par quantité < 1000 */
ORDER BY 
    total_quantity DESC;                                                            /* trie le résultat par quantité décroissante */




/* ROBOTS FACTORIES */ 

CREATE OR REPLACE VIEW ROBOTS_FACTORIES AS
SELECT 
    r.id AS robot_id,
    r.model AS robot_model,
    f.main_location AS factory_location
FROM 
    ROBOTS r
JOIN                                                                                /* jointure de robot factory, factories et robot */ 
    ROBOTS_FROM_FACTORY rf ON r.id = rf.robot_id
JOIN 
    FACTORIES f ON rf.factory_id = f.id;
