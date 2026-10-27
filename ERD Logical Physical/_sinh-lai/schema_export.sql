set QUIET 1
\pset format unaligned
\pset tuples_only on
SELECT json_build_object(
 'columns', (SELECT json_agg(json_build_object('t',c.relname,'n',a.attnum,'c',a.attname,'type',format_type(a.atttypid,a.atttypmod),
     'nn',a.attnotnull,'def',pg_get_expr(d.adbin,d.adrelid),'gen',a.attgenerated,'cmt',col_description(c.oid,a.attnum)) ORDER BY c.relname,a.attnum)
   FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace s ON s.oid=c.relnamespace
   LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum
   WHERE s.nspname='public' AND c.relkind IN ('r','p') AND a.attnum>0 AND NOT a.attisdropped),
 'cons', (SELECT json_agg(json_build_object('t',c.relname,'name',k.conname,'type',k.contype,
     'cols',(SELECT json_agg(a.attname ORDER BY x.o) FROM unnest(k.conkey) WITH ORDINALITY x(n,o) JOIN pg_attribute a ON a.attrelid=k.conrelid AND a.attnum=x.n),
     'ref',f.relname,
     'refcols',(SELECT json_agg(a.attname ORDER BY x.o) FROM unnest(k.confkey) WITH ORDINALITY x(n,o) JOIN pg_attribute a ON a.attrelid=k.confrelid AND a.attnum=x.n),
     'del',k.confdeltype,'def',pg_get_constraintdef(k.oid)) ORDER BY c.relname,k.conname)
   FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace s ON s.oid=c.relnamespace
   LEFT JOIN pg_class f ON f.oid=k.confrelid
   WHERE s.nspname='public' AND c.relkind IN ('r','p') AND k.contype IN ('p','f','u','c','x')),
 'idx', (SELECT json_agg(json_build_object('t',t.relname,'name',i.relname,'uniq',x.indisunique,'pk',x.indisprimary,'def',pg_get_indexdef(i.oid)) ORDER BY t.relname,i.relname)
   FROM pg_index x JOIN pg_class i ON i.oid=x.indexrelid JOIN pg_class t ON t.oid=x.indrelid JOIN pg_namespace s ON s.oid=t.relnamespace
   WHERE s.nspname='public' AND t.relkind IN ('r','p')),
 'enums', (SELECT json_agg(json_build_object('name',t.typname,'vals',(SELECT json_agg(e.enumlabel ORDER BY e.enumsortorder) FROM pg_enum e WHERE e.enumtypid=t.oid)))
   FROM pg_type t JOIN pg_namespace s ON s.oid=t.typnamespace WHERE s.nspname='public' AND t.typtype='e'),
 'tables', (SELECT json_agg(json_build_object('t',c.relname,'rls',c.relrowsecurity,'cmt',obj_description(c.oid,'pg_class'),'rows',c.reltuples) ORDER BY c.relname)
   FROM pg_class c JOIN pg_namespace s ON s.oid=c.relnamespace WHERE s.nspname='public' AND c.relkind IN ('r','p'))
);
