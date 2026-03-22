import React from 'react';

interface DataRow {
  [key: string]: string | number | React.ReactNode;
}

interface Column {
  key: string;
  label: string;
  width?: string;
  align?: 'left' | 'center' | 'right';
}

interface DataTableProps {
  columns: Column[];
  data: DataRow[];
  className?: string;
}

export function DataTable({ columns, data, className = '' }: DataTableProps) {
  return (
    <div className={`overflow-x-auto ${className}`}>
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-[var(--onyx-border-subtle)]">
            {columns.map((column) => (
              <th
                key={column.key}
                className={`px-3 py-2 text-xs font-semibold text-[var(--onyx-text-tertiary)] uppercase tracking-wider text-${column.align || 'left'}`}
                style={{ width: column.width }}
              >
                {column.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.map((row, rowIndex) => (
            <tr
              key={rowIndex}
              className="border-b border-[var(--onyx-border-subtle)] hover:bg-[var(--onyx-bg-hover)] transition-colors"
            >
              {columns.map((column) => (
                <td
                  key={column.key}
                  className={`px-3 py-3 text-[var(--onyx-text-secondary)] text-${column.align || 'left'}`}
                >
                  {row[column.key]}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
